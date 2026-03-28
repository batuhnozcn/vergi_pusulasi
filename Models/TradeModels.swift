import Foundation
import SwiftData

enum TradeType: String, Codable {
    case buy = "BUY"
    case sell = "SELL"
    case dividend = "DIVIDEND"
    case other = "OTHER"
}

// 1. KULLANICININ GİRDİĞİ HAM İŞLEMLER (Defter)
@Model
final class TradeTransaction {
    var id: UUID
    var ticker: String
    var typeRaw: String
    var quantity: Double
    var priceUSD: Double
    var commissionUSD: Double
    var date: Date
    var fxRate: Double
    
    // 🚨 YENİ ÇÖZÜM (Madde 10): Gerçek Sync Mimarisi (Zaman Damgası ve Soft-Delete)
    var updatedAt: Date = Date()
    var isDeleted: Bool = false
    
    // 🚀 YENİ: Verinin Sahibi (Kimlik)
        var userId: String = ""
    
    var type: TradeType {
        get { TradeType(rawValue: typeRaw) ?? .buy }
        set { typeRaw = newValue.rawValue }
    }
    
    init(id: UUID = UUID(), ticker: String, type: TradeType, quantity: Double, priceUSD: Double, commissionUSD: Double = 0, date: Date, fxRate: Double) {
        self.id = id
        self.ticker = ticker
        self.typeRaw = type.rawValue
        self.quantity = quantity
        self.priceUSD = priceUSD
        self.commissionUSD = commissionUSD
        self.date = date
        self.fxRate = fxRate
        self.updatedAt = Date() // Oluşturulma anında damgalanır
        self.isDeleted = false
    }
}

// 2. FIFO MOTORUNUN ÜRETTİĞİ VERGİLENDİRİLEBİLİR KÂR (Matrah)
struct RealizedGain: Identifiable {
    var id: UUID = UUID()
    var ticker: String
    var quantity: Double
    var buyDate: Date
    var sellDate: Date
    var buyPriceUSD: Double
    var sellPriceUSD: Double
    var buyFxRate: Double
    var sellFxRate: Double
    var profitTL: Double
    var inflationAdjustmentTL: Double
}

// 3. ELDE TUTULAN POZİSYONLAR (Envanter)
struct OpenPosition: Identifiable, Hashable {
    let id = UUID()
    let ticker: String
    let totalQuantity: Double
    let averageCostUSD: Double
    let firstBuyDate: Date
    
    // UI için kolaylık: Toplam maliyeti döndürür
    var totalCostUSD: Double {
        return totalQuantity * averageCostUSD
    }
}

// 4. SİMÜLASYON SONUCU (Gelecek Projeksiyonu)
struct SimulationResult: Identifiable {
    let id = UUID()
    let ticker: String
    let sellPriceUSD: Double
    let sellFxRate: Double
    let estimatedProfitTL: Double
    let inflationAdjustmentTL: Double
    let isInflationApplicable: Bool // %10 barajı aşıldı mı?
    
    // Vergi motorunun hesapladığı nihai matrah
    var taxableAmount: Double {
        return estimatedProfitTL
    }
}
