import SwiftUI
import FirebaseAuth

struct LoginView: View {
    @AppStorage("userName") private var userName = ""
    @AppStorage("userEmail") private var userEmail = ""
    @AppStorage("selectedTab") private var selectedTab = 0
    
    @State private var isLoginTab = true
    @StateObject private var authManager = AuthManager()
    @State private var showEmailForm = false
    
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()
                
                // Başlık ve İkon
                VStack(spacing: 20) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(hex: "1F5EFF").opacity(0.1)).frame(width: 72, height: 72)
                        Image(systemName: "wallet.pass.fill").font(.system(size: 32)).foregroundColor(Color(hex: "1F5EFF"))
                    }
                    VStack(spacing: 4) {
                        Text("Yatırımlarınızı").font(.system(size: 34, weight: .bold, design: .rounded))
                        Text("Güvenceye Alın").font(.system(size: 34, weight: .bold, design: .rounded)).foregroundColor(Color(hex: "1F5EFF"))
                    }
                    Text("Vergi hesaplamalarınızı kolaylaştırın,\nfinansal özgürlüğünüzü keşfedin.").font(.system(size: 16)).foregroundColor(.secondary).multilineTextAlignment(.center)
                }.padding(.horizontal, 24)
                
                Spacer()
                
                VStack(spacing: 16) {
                    if showEmailForm {
                        // E-POSTA FORMU
                        VStack(spacing: 12) {
                            if !isLoginTab {
                                TextField("Ad Soyad", text: $fullName).padding().background(Color(UIColor.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            TextField("E-posta Adresi", text: $email).keyboardType(.emailAddress).autocapitalization(.none).padding().background(Color(UIColor.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 14))
                            SecureField("Şifre", text: $password).padding().background(Color(UIColor.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 14))
                            if !isLoginTab {
                                SecureField("Şifreyi Tekrar Girin", text: $confirmPassword).padding().background(Color(UIColor.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            
                            if !errorMessage.isEmpty { Text(errorMessage).font(.system(size: 13)).foregroundColor(.red).padding(.top, 4) }
                            
                            Button(action: { performEmailAuth() }) {
                                HStack {
                                    if isLoading { ProgressView().tint(.white) }
                                    Text(isLoginTab ? "Giriş Yap" : "Kayıt Ol").bold()
                                }
                                .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 16).background(Color(hex: "1F5EFF")).clipShape(RoundedRectangle(cornerRadius: 14))
                            }.disabled(isLoading)
                            
                            HStack {
                                Text(isLoginTab ? "Hesabınız yok mu?" : "Zaten hesabınız var mı?").font(.system(size: 14)).foregroundColor(.secondary)
                                Button(isLoginTab ? "Kayıt Ol" : "Giriş Yap") { withAnimation { isLoginTab.toggle(); errorMessage = "" } }.font(.system(size: 14, weight: .bold)).foregroundColor(Color(hex: "1F5EFF"))
                            }.padding(.top, 8)
                            
                            Button("Vazgeç") { withAnimation { showEmailForm = false } }.font(.system(size: 14)).foregroundColor(.secondary).padding(.top, 4)
                        }
                    } else {
                        // ANA GİRİŞ BUTONLARI
                        Button(action: { loginTest() }) {
                            HStack { Image(systemName: "applelogo"); Text("Apple ile Giriş Yap").bold() }.foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 16).background(Color.black).clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        
                        Button(action: { authManager.startGoogleSignIn() }) {
                            HStack { Image(systemName: "g.circle.fill").foregroundColor(.red); Text("Google ile Giriş Yap").bold() }.foregroundColor(.primary).frame(maxWidth: .infinity).padding(.vertical, 16).background(Color(UIColor.systemBackground)).clipShape(RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gray.opacity(0.3)))
                        }
                        
                        Button("E-posta ile devam et") { withAnimation { showEmailForm = true } }.font(.system(size: 16, weight: .bold)).foregroundColor(Color(hex: "1F5EFF")).padding(.top, 8)
                    }
                }.padding(.horizontal, 24)
                
                Spacer().frame(height: 60)
            }
        }
    }
    
    private func performEmailAuth() {
        if !isLoginTab && password != confirmPassword { errorMessage = "Şifreler eşleşmiyor."; return }
        isLoading = true; errorMessage = ""
        Task {
            do {
                if isLoginTab { try await authManager.signIn(email: email, password: password) }
                else { try await authManager.signUp(email: email, password: password, fullName: fullName) }
                await MainActor.run {
                    userName = isLoginTab ? (authManager.userSession?.displayName ?? "") : fullName
                    userEmail = email
                    selectedTab = 0
                    isLoading = false
                }
            } catch {
                await MainActor.run { errorMessage = authManager.getTurkishErrorMessage(for: error); isLoading = false }
            }
        }
    }
    
    private func loginTest() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        // Apple Login entegrasyonu tamamlandığında burada AuthManager tetiklenecek
        print("Apple ile giriş tetiklendi")
    }
}
