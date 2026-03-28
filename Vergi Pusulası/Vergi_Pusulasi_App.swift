import SwiftUI
import SwiftData
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct VergiPusulasiApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    // 🚀 YENİ: StoreManager'ı uygulamanın yaşam döngüsüne bağlıyoruz
    @StateObject private var storeManager = StoreManager.shared

    var sharedModelContainer: ModelContainer = {
        // 🚨 DÜZELTME: RealizedGain.self buradan KALDIRILDI!
        let schema = Schema([TradeTransaction.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("ModelContainer oluşturulamadı: \(error)")
        }
    }()
    
    // 🚀 YENİ: Uygulama açılır açılmaz RevenueCat motorunu ateşle
    init() {
        StoreManager.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Tüm sayfalardan kullanıcının PRO durumuna (isPremium) erişilmesini sağlar
                .environmentObject(storeManager)
        }
        .modelContainer(sharedModelContainer)
    }
}
