import SwiftUI

struct LegalWarningView: View {
    @Binding var sessionTermsAccepted: Bool
    @State private var isAccepted = false
    
    var body: some View {
        VStack(spacing: 0) {
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    
                    VStack(spacing: 16) {
                        Circle()
                            .fill(Color.themePrimary.opacity(0.1))
                            .frame(width: 80, height: 80)
                            .overlay(Image(systemName: "building.columns.fill").font(.system(size: 32)).foregroundColor(.themePrimary))
                            .padding(.top, 40)
                        
                        VStack(spacing: 8) {
                            Text("ABD Borsası\nKazanç Beyanı").font(.system(size: 28, weight: .bold, design: .rounded)).foregroundColor(.primary).multilineTextAlignment(.center)
                            Text("Vergi hesaplamalarınızı kolaylaştırın.").font(.system(size: 16)).foregroundColor(.secondary)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange).font(.system(size: 18))
                            Text("Yasal Uyarı").font(.system(size: 18, weight: .bold, design: .rounded)).foregroundColor(.primary)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Bu uygulama sadece bilgilendirme amaçlıdır. Hesaplamalar tahmini değerlerdir ve kesinlik içermez.").lineSpacing(4)
                            Text("Uygulama üzerinden elde edilen sonuçlar, yatırım tavsiyesi veya resmi mali müşavirlik hizmeti yerine geçmez.").lineSpacing(4)
                        }.font(.system(size: 15)).foregroundColor(.secondary)
                    }
                    .padding(24).frame(maxWidth: .infinity, alignment: .leading).background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color(UIColor.systemBackground))).shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6).padding(.horizontal, 24)
                    
                    Spacer(minLength: 40)
                }
            }
            
            VStack(spacing: 20) {
                
                // 🚨 ÇÖZÜM: Sadece tek bir zorunlu onay kutusu kaldı
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isAccepted.toggle() }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: isAccepted ? "checkmark.square.fill" : "square").font(.system(size: 22)).foregroundColor(isAccepted ? .themePrimary : .gray.opacity(0.4))
                        Text("Aydınlatma metnini okudum ve kabul ediyorum.").font(.system(size: 14, weight: .medium)).foregroundColor(.primary).multilineTextAlignment(.leading)
                        Spacer()
                    }
                }.padding(.horizontal, 24)
                
                // DEVAM BUTONU
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    // Doğrudan oturumu geçirip ana sayfaya yönlendirir
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { sessionTermsAccepted = true }
                }) {
                    HStack(spacing: 8) { Text("Hesaplamaya Başla").font(.system(size: 18, weight: .semibold, design: .rounded)); Image(systemName: "arrow.right").font(.system(size: 16, weight: .bold)) }
                    .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 16).background(isAccepted ? Color.themePrimary : Color.themePrimary.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous)).shadow(color: isAccepted ? Color.themePrimary.opacity(0.3) : .clear, radius: 10, x: 0, y: 4)
                }.disabled(!isAccepted).padding(.horizontal, 24)
                
                Text("v1.0.2 • Güvenli Hesaplama").font(.system(size: 12)).foregroundColor(.secondary).padding(.bottom, 16)
            }
            .padding(.top, 16).background(Color.themeBackground.ignoresSafeArea(edges: .bottom).shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: -5))
        }
        .background(Color.themeBackground.ignoresSafeArea())
    }
}
