import Foundation
import RevenueCat
import SwiftUI
import Combine

@MainActor
class StoreManager: ObservableObject {
    static let shared = StoreManager()
    
    // Kullanıcının PRO olup olmadığı
    @Published var isPremium: Bool = false
    @Published var packages: [Package] = []
    
    func configure() {
        Purchases.logLevel = .debug
        // 🚨 App Store'a çıkmadan önce buradaki Test Key'in doğruluğunu RevenueCat panelinden teyit etmelisin
        Purchases.configure(withAPIKey: "test_WyDXbrakwHyhUSSWSFTeCOcuHhB")
        
        checkSubscriptionStatus()
        fetchOfferings()
    }
    
    func fetchOfferings() {
        Purchases.shared.getOfferings { offerings, error in
            if let error = error {
                print("Paketleri çekerken hata: \(error.localizedDescription)")
                return
            }
            if let currentOffering = offerings?.current {
                // Sadece aktif olan (Aylık ve Yıllık) paketleri çeker
                self.packages = currentOffering.availablePackages
            }
        }
    }
    
    func purchase(package: Package) async throws {
        let (_, customerInfo, userCancelled) = try await Purchases.shared.purchase(package: package)
        
        if userCancelled {
            print("Kullanıcı satın almaktan vazgeçti.")
            return
        }
        
        updateSubscriptionStatus(from: customerInfo)
    }
    
    func restorePurchases() async throws {
        let customerInfo = try await Purchases.shared.restorePurchases()
        updateSubscriptionStatus(from: customerInfo)
    }
    
    func checkSubscriptionStatus() {
        Purchases.shared.getCustomerInfo { customerInfo, error in
            if let customerInfo = customerInfo {
                self.updateSubscriptionStatus(from: customerInfo)
            }
        }
    }
    
    // Yetkiyi güncelleyen fonksiyon (Sadece PRO var mı yok mu diye bakar)
    private func updateSubscriptionStatus(from customerInfo: CustomerInfo) {
        // Kullanıcının RevenueCat üzerinde aktif herhangi bir yetkisi (entitlement) varsa PRO'dur.
        self.isPremium = !customerInfo.entitlements.active.isEmpty
    }
}
