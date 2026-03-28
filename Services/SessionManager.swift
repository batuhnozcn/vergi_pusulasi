import Foundation
import FirebaseAuth
import Combine

class SessionManager: ObservableObject {
    static let shared = SessionManager()
    
    @Published var isAuthenticated: Bool = false
    @Published var isAuthResolved: Bool = false // 🚀 Uygulama açılışındaki flaşı önler
    
    private var authStateListenerHandle: AuthStateDidChangeListenerHandle?
    
    private init() {
        // Firebase Auth durumunu 7/24 dinleyen kurumsal yapı
        authStateListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.isAuthenticated = (user != nil)
                self?.isAuthResolved = true
            }
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            print("Çıkış hatası: \(error.localizedDescription)")
        }
    }
}
