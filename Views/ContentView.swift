import SwiftUI
import SwiftData
import LocalAuthentication
import FirebaseFirestore
import FirebaseAuth

struct ContentView: View {
    @StateObject private var session = SessionManager.shared
    
    @AppStorage("sessionTermsAccepted") private var sessionTermsAccepted = false
    @AppStorage("isDarkModeEnabled") private var isDarkModeEnabled = false
    
    // 🚀 YENİ 1: Uygulamanın silinip tekrar yüklendiğini anlamak için bayrak
    @AppStorage("hasRunBefore") private var hasRunBefore = false
    
    @Environment(\.modelContext) private var modelContext
    @Query private var existingTransactions: [TradeTransaction]
    @State private var isSyncing = false
    
    // 🚀 YENİ 2: Akıllı Splash Ekranı kontrolü
    @State private var showSplash = true
    
    var body: some View {
        ZStack {
            // 🚀 YENİ 3: En üst katmanda her zaman Splash (Yükleniyor) ekranımız var
            if showSplash {
                CustomSplashView()
                    .transition(.opacity)
                    .zIndex(3)
            } else if !session.isAuthResolved {
                Color(UIColor.systemBackground).ignoresSafeArea()
            } else if !session.isAuthenticated {
                LoginView()
                    .transition(.opacity)
                    .zIndex(2)
            } else if !sessionTermsAccepted {
                LegalWarningView(sessionTermsAccepted: $sessionTermsAccepted)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
            } else {
                MainAppView()
                    .transition(.opacity)
                    .zIndex(0)
            }
        }
        .preferredColorScheme(isDarkModeEnabled ? .dark : .light)
        // Splash ekranı kaybolurken yumuşak bir animasyon yapar
        .animation(.easeInOut(duration: 0.6), value: showSplash)
        .animation(.easeInOut(duration: 0.3), value: session.isAuthenticated)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: sessionTermsAccepted)
        .onAppear {
            initializeApp()
        }
        .onChange(of: session.isAuthenticated) { _, newValue in
            if newValue == false { sessionTermsAccepted = false }
        }
    }
    
    private func initializeApp() {
        // 🚀 1. SİLİP YÜKLEME KONTROLÜ (Keychain'i zorla boşalt)
        if !hasRunBefore {
            do {
                try Auth.auth().signOut() // Eski Keychain kalıntılarını temizle
            } catch {
                print("Çıkış yapılamadı: \(error)")
            }
            hasRunBefore = true // Artık ilk açılış değil olarak işaretle
        }
        
        // 🚀 2. VERİLERİ BEKLE VE PERDEYİ AÇ
        Task {
            // Eğer giriş yapılmışsa önce Firebase'den verileri çek ve eşitle
            if session.isAuthResolved && session.isAuthenticated {
                await restoreFromCloud()
            }
            
            // Veri çekme çok hızlı bitse bile, o şık tasarımın hakkını vermek için en az 1.5 saniye ekranda tutalım
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            
            // Tüm işlemler bitti, perdeyi (splash ekranını) kaldır
            await MainActor.run {
                showSplash = false
            }
        }
    }
    
    // 🚀 DÜZELTME: Fonksiyon artık 'async'. Böylece bitmesini bekleyebiliyoruz.
    private func restoreFromCloud() async {
        guard !isSyncing else { return }
        
        await MainActor.run { isSyncing = true }
        let currentUserId = Auth.auth().currentUser?.uid ?? ""
        let cloudData = await FirebaseManager.shared.fetchAllFromCloud()
        
        await MainActor.run {
            let localDict = Dictionary(existingTransactions.map { ($0.id.uuidString, $0) }, uniquingKeysWith: { first, _ in first })
            var addedCount = 0
            
            for dict in cloudData {
                guard let idString = dict["id"] as? String,
                      let uuid = UUID(uuidString: idString) else { continue }
                
                let isDeleted = dict["isDeleted"] as? Bool ?? false
                let cloudUpdatedAt = (dict["updatedAt"] as? Timestamp)?.dateValue() ?? Date.distantPast
                
                if let existing = localDict[idString] {
                    if cloudUpdatedAt > existing.updatedAt {
                        if isDeleted {
                            modelContext.delete(existing)
                        } else {
                            existing.ticker = dict["ticker"] as? String ?? existing.ticker
                            existing.quantity = (dict["quantity"] as? NSNumber)?.doubleValue ?? existing.quantity
                            existing.priceUSD = (dict["priceUSD"] as? NSNumber)?.doubleValue ?? existing.priceUSD
                            existing.commissionUSD = (dict["commissionUSD"] as? NSNumber)?.doubleValue ?? existing.commissionUSD
                            existing.fxRate = (dict["fxRate"] as? NSNumber)?.doubleValue ?? existing.fxRate
                            existing.updatedAt = cloudUpdatedAt
                            existing.userId = currentUserId
                        }
                    }
                }
                else if !isDeleted {
                    if let ticker = dict["ticker"] as? String,
                       let typeRaw = dict["type"] as? String,
                       let timestamp = dict["date"] as? Timestamp {
                        
                        let quantity = (dict["quantity"] as? NSNumber)?.doubleValue ?? 0.0
                        let priceUSD = (dict["priceUSD"] as? NSNumber)?.doubleValue ?? 0.0
                        let commissionUSD = (dict["commissionUSD"] as? NSNumber)?.doubleValue ?? 0.0
                        let fxRate = (dict["fxRate"] as? NSNumber)?.doubleValue ?? 0.0
                        
                        let tradeType = TradeType(rawValue: typeRaw) ?? .buy
                        let newTx = TradeTransaction(id: uuid, ticker: ticker, type: tradeType, quantity: quantity, priceUSD: priceUSD, commissionUSD: commissionUSD, date: timestamp.dateValue(), fxRate: fxRate)
                        newTx.updatedAt = cloudUpdatedAt
                        newTx.userId = currentUserId
                        
                        modelContext.insert(newTx)
                        addedCount += 1
                    }
                }
            }
            
            if addedCount > 0 {
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
            }
            isSyncing = false
        }
    }
}

// 🚀 YENİ: Akıllı Splash Ekranı Tasarımı
struct CustomSplashView: View {
    var body: some View {
        ZStack {
            // Siyah/Lacivert arka plan garantisi (Resmin altı boş kalmasın diye)
            Color(hex: "0D1425").ignoresSafeArea()
            
            // Assets içine attığımız görseli (LaunchImage) tam ekran olarak çağırıyoruz
            Image("LaunchImage")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
        }
    }
}

// MainAppView ve LockScreenView aynı kalıyor
struct MainAppView: View {
    @AppStorage("isBiometricEnabled") private var isBiometricEnabled = false
    @Environment(\.scenePhase) var scenePhase
    @State private var isUnlocked = false
    @State private var selectedTab = 0
    @State private var showAddModal = false
    
    @State private var dashboardID = UUID()

    var body: some View {
        ZStack {
            TabView(selection: Binding(
                get: { selectedTab },
                set: { newValue in
                    if newValue == 2 { showAddModal = true }
                    else {
                        if newValue == 0 {
                            dashboardID = UUID()
                        }
                        
                        selectedTab = newValue
                        NotificationCenter.default.post(name: NSNotification.Name("ScrollToTop"), object: newValue)
                    }
                }
            )) {
                DashboardView()
                    .id(dashboardID)
                    .tabItem { Image(systemName: "house.fill"); Text("Ana Sayfa") }
                    .tag(0)
                
                AnalysisView()
                    .tabItem { Image(systemName: "chart.pie.fill"); Text("Analiz") }
                    .tag(1)
                
                Text("")
                    .tabItem { Image(systemName: "plus.circle.fill"); Text("Ekle") }
                    .tag(2)
                
                ReportsView()
                    .tabItem { Image(systemName: "doc.text.fill"); Text("Raporlar") }
                    .tag(3)
                
                SettingsView()
                    .tabItem { Image(systemName: "gearshape.fill"); Text("Ayarlar") }
                    .tag(4)
            }
            .tint(Color(hex: "1F5EFF"))
            
            if isBiometricEnabled && !isUnlocked { LockScreenView(isUnlocked: $isUnlocked) }
        }
        .sheet(isPresented: $showAddModal) { AddTransactionView() }
        .onChange(of: scenePhase) { oldPhase, newPhase in if isBiometricEnabled && newPhase == .background { isUnlocked = false } }
        .onAppear { if isBiometricEnabled && !isUnlocked { authenticate() } }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DismissModalAndGoHome"))) { _ in
            showAddModal = false
            selectedTab = 0
            dashboardID = UUID()
            NotificationCenter.default.post(name: NSNotification.Name("ScrollToTop"), object: 0)
        }
    }
    
    private func authenticate() { let context = LAContext(); var error: NSError?; if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) { context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Uygulamaya giriş yapmak için yüzünüzü okutun.") { success, _ in DispatchQueue.main.async { if success { self.isUnlocked = true } } } } }
}

struct LockScreenView: View {
    @Binding var isUnlocked: Bool
    var body: some View {
        ZStack {
            Color(hex: "0D1425").ignoresSafeArea()
            VStack(spacing: 32) {
                Image(systemName: "lock.shield.fill").font(.system(size: 80)).foregroundColor(Color(hex: "1F5EFF")).shadow(color: Color(hex: "1F5EFF").opacity(0.5), radius: 20, y: 10)
                VStack(spacing: 8) { Text("Vergi Pusulası Kilitli").font(.system(size: 24, weight: .bold)).foregroundColor(.white); Text("Finansal verilerinizi görmek için kilidi açın.").font(.system(size: 14)).foregroundColor(.white.opacity(0.7)) }
                Button(action: authenticate) { HStack { Image(systemName: "faceid"); Text("Face ID ile Aç") }.font(.system(size: 16, weight: .bold)).foregroundColor(.white).padding(.horizontal, 32).padding(.vertical, 16).background(Color(hex: "1F5EFF")).clipShape(Capsule()).shadow(color: Color(hex: "1F5EFF").opacity(0.3), radius: 10, y: 5) }.padding(.top, 24)
            }
        }
    }
    private func authenticate() { let context = LAContext(); var error: NSError?; if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) { context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Kilit açılıyor...") { success, _ in DispatchQueue.main.async { if success { self.isUnlocked = true } } } } }
}
