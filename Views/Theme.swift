import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }

    // AÇIK TEMA RENKLERİ
    static let themeBackground = Color(hex: "F2F4F7") // Çok hafif gri/mavi ferah arka plan
    static let themeCard = Color.white               // Bembeyaz kartlar
    static let themePrimary = Color(hex: "1F5EFF")   // İmza mavi rengimiz aynı kalıyor
    static let themeAccent = Color(hex: "10B981")    // Açık temada daha okunaklı yeşil
    static let themeTextSecondary = Color(hex: "64748B") // Şık bir arduvaz grisi
}

extension Double {
    func toCurrency() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₺"
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter.string(from: NSNumber(value: self)) ?? "₺0,00"
    }
}

// MARK: - Modern Tasarım Bileşenleri

struct StatusTag: View {
    let text: String; let color: Color
    var body: some View {
        Text(text).font(.system(size: 11, weight: .bold))
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(color.opacity(0.12)).foregroundStyle(color).clipShape(Capsule())
    }
}

struct InfoCard: View {
    let title: String; let value: String; let trend: String; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                Text(trend).font(.system(size: 10, weight: .bold)).foregroundStyle(color)
            }
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6) // Miktarlar uzarsa fontu küçülterek ekrana sığdırır
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.themeCard))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.black.opacity(0.03), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.02), radius: 8, x: 0, y: 2)
    }
}
