import Foundation
import FirebaseAuth
import SwiftUI
import Combine
import AuthenticationServices
import CryptoKit
import GoogleSignIn // 🚨 Yeni eklendi

@MainActor
class AuthManager: NSObject, ObservableObject, ASAuthorizationControllerDelegate {
    
    @Published var userSession: FirebaseAuth.User?
    @Published var isAuthenticated = false
    
    fileprivate var currentNonce: String?
    
    override init() {
        super.init()
        self.userSession = Auth.auth().currentUser
        self.isAuthenticated = self.userSession != nil
    }
    
    // MARK: - E-POSTA İŞLEMLERİ
    func signIn(email: String, password: String) async throws {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        self.userSession = result.user
        self.isAuthenticated = true
    }
    
    func signUp(email: String, password: String, fullName: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        let changeRequest = result.user.createProfileChangeRequest()
        changeRequest.displayName = fullName
        try await changeRequest.commitChanges()
        self.userSession = Auth.auth().currentUser
        self.isAuthenticated = true
    }
    
    // MARK: - GOOGLE İLE GİRİŞ (🚨 YENİ)
    func startGoogleSignIn() {
        // Uygulamanın en üst penceresini bul (Pencereyi açmak için şart)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else { return }
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { signInResult, error in
            if let error = error {
                print("Google Giriş Hatası: \(error.localizedDescription)")
                return
            }
            
            guard let user = signInResult?.user,
                  let idToken = user.idToken?.tokenString else { return }
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                           accessToken: user.accessToken.tokenString)
            
            Task { @MainActor in
                do {
                    let result = try await Auth.auth().signIn(with: credential)
                    
                    let fullName = result.user.displayName ?? ""
                    let email = result.user.email ?? ""
                    
                    // Bilgileri yerel hafızaya kaydet
                    UserDefaults.standard.set(fullName, forKey: "userName")
                    UserDefaults.standard.set(email, forKey: "userEmail")
                    UserDefaults.standard.set(0, forKey: "selectedTab")
                    
                    self.userSession = result.user
                    self.isAuthenticated = true
                    
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        UserDefaults.standard.set(true, forKey: "userSessionActive")
                    }
                } catch {
                    print("Firebase Google Kayıt Hatası: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - APPLE İLE GİRİŞ
    func startAppleSignIn() {
        let nonce = randomNonceString()
        currentNonce = nonce
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.performRequests()
    }
    
    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            guard let appleIDToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: appleIDToken, encoding: .utf8) else { return }
            
            Task { @MainActor in
                guard let nonce = self.currentNonce else { return }
                
                let credential = OAuthProvider.appleCredential(withIDToken: idTokenString,
                                                               rawNonce: nonce,
                                                               fullName: appleIDCredential.fullName)
                
                let fullNameStr = [appleIDCredential.fullName?.givenName, appleIDCredential.fullName?.familyName]
                    .compactMap({ $0 })
                    .joined(separator: " ")
                
                do {
                    let result = try await Auth.auth().signIn(with: credential)
                    if !fullNameStr.isEmpty {
                        let changeRequest = result.user.createProfileChangeRequest()
                        changeRequest.displayName = fullNameStr
                        try await changeRequest.commitChanges()
                        UserDefaults.standard.set(fullNameStr, forKey: "userName")
                    }
                    if let email = result.user.email { UserDefaults.standard.set(email, forKey: "userEmail") }
                    
                    UserDefaults.standard.set(0, forKey: "selectedTab")
                    self.userSession = result.user
                    self.isAuthenticated = true
                    
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        UserDefaults.standard.set(true, forKey: "userSessionActive")
                    }
                } catch {
                    print("Apple Auth Hatası: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - YARDIMCI METODLAR
    func signOut() {
        do {
            try Auth.auth().signOut()
            self.userSession = nil
            self.isAuthenticated = false
        } catch {
            print("Çıkış hatası")
        }
    }
    
    func getTurkishErrorMessage(for error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == AuthErrorDomain {
            if let authErrorCode = AuthErrorCode(rawValue: nsError.code) {
                switch authErrorCode {
                case .invalidEmail: return "Geçersiz bir e-posta adresi girdiniz."
                case .emailAlreadyInUse: return "Bu e-posta adresi zaten kullanımda."
                case .weakPassword: return "Şifreniz çok zayıf. En az 6 karakter olmalı."
                case .wrongPassword, .userNotFound, .invalidCredential: return "E-posta veya şifre hatalı."
                case .networkError: return "İnternet bağlantınızı kontrol edin."
                default: return "İşlem başarısız oldu."
                }
            }
        }
        return "Bilinmeyen bir hata oluştu."
    }
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                _ = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                return random
            }
            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}
