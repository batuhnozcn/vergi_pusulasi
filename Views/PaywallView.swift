import SwiftUI
import RevenueCat

struct PaywallView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var storeManager: StoreManager
    
    @State private var selectedPackage: Package? = nil
    @State private var isPurchasing = false
    
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    // Yasal Linkler (Apple incelemesi için zorunludur)
    let privacyURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")! // Şimdilik Apple standart sözleşmesi
    let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    
    var body: some View {
        ZStack {
            Color(hex: "0D1425").ignoresSafeArea()
            
            Circle()
                .fill(Color(hex: "1F5EFF").opacity(0.3))
                .blur(radius: 100)
                .frame(width: 300, height: 300)
                .offset(x: 100, y: -200)
            
            VStack(spacing: 0) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        
                        VStack(spacing: 16) {
                            Image(systemName: "shield.checkered")
                                .font(.system(size: 64, weight: .light))
                                .foregroundColor(Color(hex: "1F5EFF"))
                            
                            VStack(spacing: 8) {
                                HStack(spacing: 0) {
                                    Text("Vergi Pusulası")
                                        .foregroundColor(.white)
                                    Text(" PRO")
                                        .foregroundColor(Color(hex: "1F5EFF"))
                                }
                                .font(.system(size: 28, weight: .heavy, design: .rounded))
                                
                                Text("Yatırımlarınızı koruyun, vergiden tasarruf edin.")
                                    .font(.system(size: 15))
                                    .foregroundColor(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                            }
                        }
                        .padding(.top, 16)
                        
                        VStack(alignment: .leading, spacing: 20) {
                            FeatureRow(icon: "doc.text.viewfinder", title: "Mali Müşavir Formatında PDF", subtitle: "İşlemlerinizi tek tıkla resmi vergi raporuna dönüştürün.")
                            FeatureRow(icon: "chart.line.uptrend.xyaxis", title: "Yİ-ÜFE Enflasyon Kalkanı", subtitle: "Yasal enflasyon endekslemesi ile hayali kâr vergisinden kurtulun.")
                            FeatureRow(icon: "infinity", title: "Sınırsız İşlem Takibi", subtitle: "Hisse senedi ve temettü işlemlerinizi sınır olmadan ekleyin.")
                            FeatureRow(icon: "arrow.triangle.2.circlepath", title: "Otomatik TCMB Kur Çevirisi", subtitle: "T-1 kurları geriye dönük olarak otomatik hesaplansın.")
                        }
                        .padding(.horizontal, 32)
                        
                        // FİYATLANDIRMA KARTLARI
                        if storeManager.packages.isEmpty {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .padding()
                        } else {
                            VStack(spacing: 16) {
                                ForEach(storeManager.packages, id: \.identifier) { package in
                                    createPlanCard(for: package)
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                        
                        VStack(spacing: 16) {
                            Button(action: {
                                guard let package = selectedPackage else { return }
                                isPurchasing = true
                                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                
                                Task {
                                    do {
                                        try await storeManager.purchase(package: package)
                                        isPurchasing = false
                                        if storeManager.isPremium { dismiss() }
                                    } catch {
                                        isPurchasing = false
                                        if let rcError = error as? RevenueCat.ErrorCode, rcError == .purchaseCancelledError {
                                            // Kullanıcı vazgeçti, sessizce geç
                                        } else {
                                            alertTitle = "İşlem Başarısız"
                                            alertMessage = error.localizedDescription
                                            showAlert = true
                                        }
                                    }
                                }
                            }) {
                                HStack {
                                    if isPurchasing {
                                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Text("Premium'a Yükselt")
                                            .font(.system(size: 18, weight: .bold))
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(Color(hex: "1F5EFF"))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: Color(hex: "1F5EFF").opacity(0.5), radius: 15, y: 8)
                                .opacity(selectedPackage == nil || isPurchasing ? 0.6 : 1.0)
                            }
                            .disabled(selectedPackage == nil || isPurchasing)
                            .padding(.horizontal, 24)
                            
                            // YASAL LİNKLER VE GERİ YÜKLE
                            HStack(spacing: 16) {
                                Link("Kullanım Şartları", destination: termsURL)
                                    .font(.system(size: 11)).foregroundColor(.gray)
                                
                                Circle().frame(width: 3, height: 3).foregroundColor(.gray)
                                
                                Button(action: {
                                    isPurchasing = true
                                    Task {
                                        do {
                                            try await storeManager.restorePurchases()
                                            isPurchasing = false
                                            if storeManager.isPremium {
                                                dismiss()
                                            } else {
                                                alertTitle = "Abonelik Bulunamadı"
                                                alertMessage = "Bu Apple kimliğine bağlı aktif bir 'Vergi Pusulası PRO' aboneliği bulunamadı."
                                                showAlert = true
                                            }
                                        } catch {
                                            isPurchasing = false
                                            alertTitle = "Bağlantı Hatası"
                                            alertMessage = "Geri yükleme işlemi sırasında bir hata oluştu."
                                            showAlert = true
                                        }
                                    }
                                }) {
                                    Text("Geri Yükle").font(.system(size: 11, weight: .semibold)).foregroundColor(.white.opacity(0.8))
                                }
                                
                                Circle().frame(width: 3, height: 3).foregroundColor(.gray)
                                
                                Link("Gizlilik Politikası", destination: privacyURL)
                                    .font(.system(size: 11)).foregroundColor(.gray)
                            }
                            .padding(.bottom, 24)
                        }
                    }
                }
            }
        }
        .onAppear {
            // Açılışta varsayılan olarak Yıllık paketi seç
            if let firstPackage = storeManager.packages.first(where: { $0.packageType == .annual }) ?? storeManager.packages.first {
                selectedPackage = firstPackage
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text(alertTitle),
                  message: Text(alertMessage),
                  dismissButton: .default(Text("Tamam")))
        }
    }
    
    // MÜŞAVİR MANTIĞI SİLİNDİ, SADECE AYLIK VE YILLIK KALDI
    private func createPlanCard(for package: Package) -> some View {
        let isAnnual = package.packageType == .annual
        
        let titleText = isAnnual ? "Yıllık Plan" : "Aylık Plan"
        let durationText = isAnnual ? "/ yıl" : "/ ay"
        
        return PlanCard(
            title: titleText,
            price: package.localizedPriceString,
            duration: durationText,
            isPopular: isAnnual,
            isSelected: selectedPackage?.identifier == package.identifier
        ) {
            selectedPackage = package
        }
    }
}

// MARK: - ALT BİLEŞENLER

struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle().fill(Color(hex: "1F5EFF").opacity(0.1)).frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color(hex: "1F5EFF"))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                Text(subtitle).font(.system(size: 13)).foregroundColor(.white.opacity(0.6)).lineSpacing(2)
            }
        }
    }
}

struct PlanCard: View {
    let title: String
    let price: String
    let duration: String
    let isPopular: Bool
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title).font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                        if isPopular {
                            Text("EN AVANTAJLI")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color(hex: "1F5EFF"))
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(price).font(.system(size: 24, weight: .bold, design: .rounded)).foregroundColor(.white)
                        Text(duration).font(.system(size: 14)).foregroundColor(.white.opacity(0.6))
                    }
                }
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color(hex: "1F5EFF") : Color.white.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(Color(hex: "1F5EFF"))
                            .frame(width: 14, height: 14)
                    }
                }
            }
            .padding(20)
            .background(isSelected ? Color(hex: "1F5EFF").opacity(0.1) : Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color(hex: "1F5EFF") : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
