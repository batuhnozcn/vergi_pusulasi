import Foundation
import FirebaseAuth

@MainActor
class AuthManager: ObservableObject {
    
    // Kullanıcının oturum durumunu tüm uygulamaya anlık (Canlı) olarak bildirir
    @Published var userSession: FirebaseAuth.User?
    @Published var isAuthenticated = false
    
    init() {
        // Uygulama açıldığında daha önce giriş yapmış bir kullanıcı var mı diye bakar
        self.userSession = Auth.auth().currentUser
        self.isAuthenticated = self.userSession != nil
    }
    
    // 1. GİRİŞ YAP (Sign In)
    func signIn(email: String, password: String) async throws {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        self.userSession = result.user
        self.isAuthenticated = true
    }
    
    // 2. KAYIT OL (Sign Up)
    func signUp(email: String, password: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        self.userSession = result.user
        self.isAuthenticated = true
    }
    
    // 3. ÇIKIŞ YAP (Sign Out)
    func signOut() {
        do {
            try Auth.auth().signOut()
            self.userSession = nil
            self.isAuthenticated = false
        } catch {
            print("Çıkış yapılırken bir hata oluştu: \(error.localizedDescription)")
        }
    }
}
