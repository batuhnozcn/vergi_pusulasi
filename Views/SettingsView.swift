import SwiftUI
import LocalAuthentication
import UserNotifications
import FirebaseAuth

struct SettingsView: View {
    @AppStorage("userName") private var userName = "Kullanıcı"
    @AppStorage("userEmail") private var userEmail = "hesap@ornek.com"
    @AppStorage("isDarkModeEnabled") private var isDarkModeEnabled = false
    @AppStorage("isBiometricEnabled") private var isBiometricEnabled = false
    @AppStorage("isNotificationsEnabled") private var isNotificationsEnabled = false
    @AppStorage("profileImageData") private var profileImageData: Data?
    
    @State private var showingBiometricError = false
    @State private var showingNotificationAlert = false
    @State private var showPaywall = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            Color.clear.frame(height: 0).id("top")
                            
                            Text("Ayarlar")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 24)
                                .padding(.top, 16)
                            
                            // 1. PROFİL KARTI
                            NavigationLink(destination: ProfileEditView()) {
                                HStack(spacing: 16) {
                                    if let data = profileImageData, let uiImage = UIImage(data: data) {
                                        Image(uiImage: uiImage).resizable().scaledToFill().frame(width: 56, height: 56).clipShape(Circle())
                                    } else {
                                        Circle().fill(Color(hex: "FFE4C4")).frame(width: 56, height: 56).overlay(Image(systemName: "person.fill").resizable().scaledToFit().frame(width: 30).foregroundColor(Color.orange.opacity(0.5)).offset(y: 5).clipShape(Circle()))
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(userName).font(.system(size: 18, weight: .bold)).foregroundColor(.primary)
                                        Text(userEmail).font(.system(size: 14)).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Circle().fill(Color(hex: "1F5EFF")).frame(width: 32, height: 32).overlay(Image(systemName: "pencil").font(.system(size: 14, weight: .bold)).foregroundColor(.white))
                                }.padding(16).background(Color(UIColor.secondarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 16))
                            }.padding(.horizontal, 24)
                            
                            // 2. PREMIUM (PRO) AFİŞİ
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                showPaywall = true
                            }) {
                                HStack(spacing: 16) {
                                    ZStack {
                                        Circle().fill(Color.white.opacity(0.2)).frame(width: 44, height: 44)
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundColor(.yellow)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 4) {
                                            Text("Vergi Pusulası")
                                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                                .foregroundColor(.white)
                                            Text("PRO")
                                                .font(.system(size: 16, weight: .black, design: .rounded))
                                                .foregroundColor(Color(hex: "FFD700"))
                                        }
                                        Text("Sınırsız PDF Raporu & Enflasyon Kalkanı")
                                            .font(.system(size: 12))
                                            .foregroundColor(.white.opacity(0.8))
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                .padding(16)
                                .background(
                                    LinearGradient(colors: [Color(hex: "0D1425"), Color(hex: "1F5EFF")], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: Color(hex: "1F5EFF").opacity(0.3), radius: 10, y: 5)
                            }
                            .padding(.horizontal, 24)
                            
                            // 3. UYGULAMA TERCİHLERİ
                            VStack(alignment: .leading, spacing: 12) {
                                Text("UYGULAMA").font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary).padding(.horizontal, 8)
                                VStack(spacing: 0) {
                                    SettingsToggleRow(icon: "moon.fill", iconBg: Color.gray.opacity(0.2), iconFg: .primary, title: "Karanlık Mod", isOn: $isDarkModeEnabled)
                                    Divider().padding(.leading, 56)
                                    
                                    HStack(spacing: 16) {
                                        ZStack { RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.15)).frame(width: 32, height: 32); Image(systemName: "bell.fill").font(.system(size: 16)).foregroundColor(.red) }
                                        Text("Bildirimler").font(.system(size: 16, weight: .medium)).foregroundColor(.primary)
                                        Spacer()
                                        Toggle("", isOn: Binding(get: { isNotificationsEnabled }, set: { newValue in if newValue { requestNotificationPermission() } else { isNotificationsEnabled = false } })).labelsHidden().tint(Color(hex: "1F5EFF"))
                                    }.padding(.horizontal, 16).padding(.vertical, 12)
                                    
                                    Divider().padding(.leading, 56)
                                    
                                    HStack(spacing: 16) {
                                        ZStack { RoundedRectangle(cornerRadius: 8).fill(Color.purple.opacity(0.15)).frame(width: 32, height: 32); Image(systemName: "faceid").font(.system(size: 16)).foregroundColor(.purple) }
                                        Text("Face ID ile Giriş").font(.system(size: 16, weight: .medium)).foregroundColor(.primary)
                                        Spacer()
                                        Toggle("", isOn: Binding(get: { isBiometricEnabled }, set: { newValue in authenticateBiometrics(newValue: newValue) })).labelsHidden().tint(Color(hex: "1F5EFF"))
                                    }.padding(.horizontal, 16).padding(.vertical, 12)
                                }.background(Color(UIColor.secondarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 16))
                            }.padding(.horizontal, 24)
                            
                            // 4. DESTEK VE HAKKINDA
                            VStack(alignment: .leading, spacing: 12) {
                                Text("DESTEK VE HAKKINDA").font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary).padding(.horizontal, 8)
                                VStack(spacing: 0) {
                                    
                                    NavigationLink(destination: LegalDocumentView(documentType: .terms)) {
                                        SettingsStaticRow(icon: "doc.text.fill", iconBg: Color.orange.opacity(0.15), iconFg: .orange, title: "Kullanım Şartları")
                                    }.buttonStyle(PlainButtonStyle())
                                    
                                    Divider().padding(.leading, 56)
                                    
                                    NavigationLink(destination: LegalDocumentView(documentType: .privacy)) {
                                        SettingsStaticRow(icon: "shield.fill", iconBg: Color.blue.opacity(0.15), iconFg: .blue, title: "Gizlilik Politikası")
                                    }.buttonStyle(PlainButtonStyle())
                                    
                                    Divider().padding(.leading, 56)
                                    
                                    NavigationLink(destination: FAQView()) {
                                        SettingsStaticRow(icon: "questionmark.circle.fill", iconBg: Color.green.opacity(0.15), iconFg: .green, title: "Sıkça Sorulan Sorular")
                                    }.buttonStyle(PlainButtonStyle())
                                    
                                }.background(Color(UIColor.secondarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 16))
                            }.padding(.horizontal, 24)
                            
                            // 5. ÇIKIŞ YAP
                            VStack(spacing: 16) {
                                VStack(spacing: 8) {
                                    ZStack { RoundedRectangle(cornerRadius: 12).fill(Color(hex: "1F5EFF").opacity(0.1)).frame(width: 48, height: 48); Image(systemName: "plus.forwardslash.minus").font(.system(size: 20, weight: .bold)).foregroundColor(Color(hex: "1F5EFF")) }
                                    Text("Vergi Pusulası").font(.system(size: 14, weight: .medium)).foregroundColor(.secondary)
                                    Text("Versiyon 1.0.0").font(.system(size: 12)).foregroundColor(.secondary.opacity(0.7))
                                }.padding(.top, 16)
                                
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    // 🚀 Çıkış işlemi doğrudan SessionManager'a devredildi
                                    SessionManager.shared.signOut()
                                }) {
                                    Text("Çıkış Yap")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.red)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(Color(UIColor.secondarySystemGroupedBackground))
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                }
                            }.padding(.horizontal, 24)
                            
                            Spacer(minLength: 40)
                        }
                    }
                    .onAppear {
                        proxy.scrollTo("top", anchor: .top)
                        if let user = Auth.auth().currentUser {
                            if let email = user.email { userEmail = email }
                            if let name = user.displayName, !name.isEmpty { userName = name }
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ScrollToTop"))) { notif in
                        if let tab = notif.object as? Int, tab == 4 {
                            withAnimation { proxy.scrollTo("top", anchor: .top) }
                        }
                    }
                }
            }
            .alert("Bildirim İzni", isPresented: $showingNotificationAlert) {
                Button("İptal", role: .cancel) { isNotificationsEnabled = false }
                Button("Ayarlara Git") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
            } message: { Text("Bildirim alabilmek için cihaz ayarlarından izin vermeniz gerekmektedir.") }
            .alert("Face ID Hatası", isPresented: $showingBiometricError) { Button("Tamam", role: .cancel) { } } message: { Text("Biyometrik doğrulama başarısız oldu veya cihazınızda ayarlı değil.") }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }
    
    private func authenticateBiometrics(newValue: Bool) { let context = LAContext(); var error: NSError?; if newValue { if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) { context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Uygulama güvenliğini etkinleştirmek için onayınız gerekiyor.") { success, _ in DispatchQueue.main.async { if success { self.isBiometricEnabled = true } else { self.isBiometricEnabled = false; self.showingBiometricError = true } } } } else { self.isBiometricEnabled = false; self.showingBiometricError = true } } else { self.isBiometricEnabled = false } }
    
    private func requestNotificationPermission() { UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, _ in DispatchQueue.main.async { self.isNotificationsEnabled = success; if !success { self.showingNotificationAlert = true } } } }
}

// MARK: - ALT BİLEŞENLER
struct SettingsStaticRow: View {
    let icon: String; let iconBg: Color; let iconFg: Color; let title: String; var value: String? = nil
    var body: some View {
        HStack(spacing: 16) {
            ZStack { RoundedRectangle(cornerRadius: 8).fill(iconBg).frame(width: 32, height: 32); Image(systemName: icon).font(.system(size: 16)).foregroundColor(iconFg) }
            Text(title).font(.system(size: 16, weight: .medium)).foregroundColor(.primary)
            Spacer()
            if let val = value { Text(val).font(.system(size: 16)).foregroundColor(.secondary) }
            Image(systemName: "chevron.right").font(.system(size: 14)).foregroundColor(.secondary.opacity(0.5))
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

struct SettingsToggleRow: View {
    let icon: String; let iconBg: Color; let iconFg: Color; let title: String; @Binding var isOn: Bool
    var body: some View {
        HStack(spacing: 16) {
            ZStack { RoundedRectangle(cornerRadius: 8).fill(iconBg).frame(width: 32, height: 32); Image(systemName: icon).font(.system(size: 16)).foregroundColor(iconFg) }
            Text(title).font(.system(size: 16, weight: .medium)).foregroundColor(.primary)
            Spacer()
            Toggle("", isOn: $isOn).labelsHidden().tint(Color(hex: "1F5EFF"))
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }
}

enum LegalDocumentType {
    case privacy
    case terms
    
    var title: String {
        switch self {
        case .privacy: return "Gizlilik Politikası"
        case .terms: return "Kullanım Şartları"
        }
    }
    
    var content: String {
        switch self {
        case .privacy:
            return """
            Vergi Pusulası olarak finansal verilerinizin güvenliği bizim için en yüksek önceliktir.
            
            1. Veri Toplama: Uygulamamız, vergi hesaplamalarınızı yapabilmek için yalnızca sizin yüklediğiniz finansal işlem geçmişinizi (hisse senedi alım/satım, temettü vs.) toplar.
            
            2. Veri Güvenliği: Finansal verileriniz cihazınızda ve güvenli bulut altyapımızda şifrelenmiş olarak saklanmaktadır. Verileriniz hiçbir şekilde üçüncü taraf kurum veya kişilerle paylaşılmaz veya satılmaz.
            
            3. Hesap Silme: Uygulama içerisinden hesabınızı ve tüm verilerinizi dilediğiniz an kalıcı olarak silebilirsiniz. Silme işlemi sonrasında verileriniz sunucularımızdan tamamen yok edilir.
            """
        case .terms:
            return """
            Vergi Pusulası uygulamasını kullanarak aşağıdaki şartları kabul etmiş sayılırsınız:
            
            1. Sorumluluk Reddi: Vergi Pusulası, geçmiş verilerinize dayanarak tahmini bir vergi hesaplaması sunan bir yardımcı araçtır. Uygulamanın sunduğu vergi matrahı veya ödenecek vergi tutarları kesin bir yasal beyanname niteliği taşımaz.
            
            2. Mali Müşavir Onayı: Uygulamanın ürettiği PDF raporları bilgilendirme amaçlıdır. Resmi vergi beyannamenizi (Hazır Beyan Sistemi) doldurmadan önce verilerinizi mutlaka bir Serbest Muhasebeci Mali Müşavir (SMMM) ile doğrulamanız gerekmektedir.
            
            3. Vergi Cezaları: Uygulamadaki olası hesaplama farklılıklarından doğabilecek vergi ziyaı cezaları veya gecikme faizlerinden Vergi Pusulası sorumlu tutulamaz.
            """
        }
    }
}

struct LegalDocumentView: View {
    let documentType: LegalDocumentType
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(documentType.content)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .lineSpacing(6)
            }
            .padding(24)
        }
        .navigationTitle(documentType.title)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
    }
}

struct FAQItem: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
}

struct FAQView: View {
    @State private var expandedItem: UUID? = nil
    
    let faqs: [FAQItem] = [
        FAQItem(question: "Yİ-ÜFE Enflasyon Kalkanı nedir?", answer: "Vergi kanunlarına göre, hisse senedi alım ve satım tarihleri arasındaki Yİ-ÜFE (Yurt İçi Üretici Fiyat Endeksi) artışı %10'un üzerindeyse, hisse maliyetiniz bu enflasyon oranında yasal olarak artırılır. Bu sayede enflasyon kaynaklı 'hayali kâr' üzerinden vergi ödemekten kurtulursunuz."),
        FAQItem(question: "Temettü gelirleri nasıl vergilendirilir?", answer: "Yurtdışı borsalarından elde edilen temettü gelirleri doğrudan beyana tabidir. Ancak, ilgili ülkede (örneğin ABD'de %20) kesilen stopaj vergileri, Türkiye'de hesaplanan gelir vergisinden mahsup edilebilir (düşülebilir)."),
        FAQItem(question: "Zarar realizasyonu (Tax Loss Harvesting) ne işe yarar?", answer: "Portföyünüzde zararda olan hisseleri satıp aynı gün veya ertesi gün geri alarak yasal bir zarar oluşturursunuz. Bu zarar, diğer kârlı hisse satışlarınızdan mahsup edilerek toplam vergi matrahınızı ve ödeyeceğiniz vergiyi yasal olarak düşürür."),
        FAQItem(question: "Hesaplamalarım neden GİB Hazır Beyan ile tam tutmuyor?", answer: "Kur çevrimlerinde TCMB alış kurları kullanılır. İşlem saatlerindeki farklılıklar, kuruşluk yuvarlamalar veya platformunuzun uyguladığı spesifik komisyon/masraf kesintileri nedeniyle Hazır Beyan sistemindeki nihai tutarlarla çok küçük farklılıklar oluşabilir.")
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(faqs) { faq in
                    FAQRow(faq: faq, isExpanded: expandedItem == faq.id) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            expandedItem = expandedItem == faq.id ? nil : faq.id
                        }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Sıkça Sorulan Sorular")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
    }
}

struct FAQRow: View {
    let faq: FAQItem
    let isExpanded: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onTap) {
                HStack(alignment: .top) {
                    Text(faq.question)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(hex: "1F5EFF"))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(16)
                .background(Color(UIColor.secondarySystemGroupedBackground))
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                Text(faq.answer)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.02), radius: 5, y: 2)
    }
}
