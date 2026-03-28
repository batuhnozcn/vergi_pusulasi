import Foundation
import SwiftData
import FirebaseFirestore // 🚀 YENİ EKLENDİ

// 🚀 YENİ: View'ların ihtiyaç duyacağı her şeyi tek bir pakette (DTO) topladık
struct TaxSummary {
    let totalTax: Double         // Stopaj sonrası ödenecek NET vergi
    let grossTax: Double         // Stopaj öncesi BRÜT vergi (Raporlardaki 5.767 TL)
    let netProfit: Double        // Yasal Matraha giren hisse kârı
    let grossStockProfit: Double // Kalkan öncesi, zararlar düşülmüş CEPTEKİ ham hisse kârı
    let grossTotalIncome: Double // Hisse kârı + Temettü + Diğer (Raporlardaki 406.363 TL)
    let taxBase: Double
    let needsDeclaration: Bool
    let dividendTotal: Double
    let otherIncome: Double
    let inflationAdvantage: Double
    let foreignTaxCredit: Double
    let potentialTaxSavings: Double
    let bracketInfo: BracketInfo // Ana Sayfa'daki bar için
}

struct TaxBracket {
    let limit: Double
    let rate: Double
}

struct BracketInfo {
    let rate: Int
    let progress: Double
    let remaining: Double
    let bracketIndex: Int
}

class TaxComputationService {
    static let shared = TaxComputationService()
    
    // 🚀 YENİ: Firebase'den gelecek dinamik sınırları tutan sözlük
    private var remoteDividendLimits: [Int: Double] = [:]
    
    private init() {}
    
    // 🚀 YENİ: Açılışta çalışıp güncel sınırları buluttan çeker
    func fetchRemoteTaxConfig() async {
        let db = Firestore.firestore()
        do {
            let snapshot = try await db.collection("config").document("tax_limits").getDocument()
            if let data = snapshot.data(), let limits = data["dividendLimits"] as? [String: Double] {
                var parsedLimits: [Int: Double] = [:]
                for (key, value) in limits {
                    if let year = Int(key) {
                        parsedLimits[year] = value
                    }
                }
                self.remoteDividendLimits = parsedLimits
            }
        } catch {
            print("Firebase vergi sınırları çekilemedi: \(error.localizedDescription)")
        }
    }
    
    private func getBrackets(for year: Int) -> [TaxBracket] {
        switch year {
        case 2023: return [ TaxBracket(limit: 70_000, rate: 0.15), TaxBracket(limit: 150_000, rate: 0.20), TaxBracket(limit: 370_000, rate: 0.27), TaxBracket(limit: 1_900_000, rate: 0.35), TaxBracket(limit: .infinity, rate: 0.40) ]
        case 2024: return [ TaxBracket(limit: 110_000, rate: 0.15), TaxBracket(limit: 230_000, rate: 0.20), TaxBracket(limit: 870_000, rate: 0.27), TaxBracket(limit: 3_000_000, rate: 0.35), TaxBracket(limit: .infinity, rate: 0.40) ]
        case 2025: return [ TaxBracket(limit: 158_000, rate: 0.15), TaxBracket(limit: 330_000, rate: 0.20), TaxBracket(limit: 800_000, rate: 0.27), TaxBracket(limit: 4_300_000, rate: 0.35), TaxBracket(limit: .infinity, rate: 0.40) ]
        default: return [ TaxBracket(limit: 227_000, rate: 0.15), TaxBracket(limit: 475_000, rate: 0.20), TaxBracket(limit: 1_720_000, rate: 0.27), TaxBracket(limit: 6_190_000, rate: 0.35), TaxBracket(limit: .infinity, rate: 0.40) ]
        }
    }
    
    private func getDividendDeclarationLimit(for year: Int) -> Double {
        // 🚀 DİNAMİK KONTROL: Eğer o yılın sınırı Firebase'den gelmişse doğrudan onu kullan.
        if let remoteLimit = remoteDividendLimits[year] {
            return remoteLimit
        }
        
        // 🚀 RESMİ GÜNCELLEME: Firebase'e ulaşılamazsa GVK 86/1-d resmi tebliğ rakamları kullanılır.
        switch year {
        case 2023: return 8_400
        case 2024: return 13_000
        case 2025: return 18_000
        case 2026: return 22_000 // 332 Seri No.lu Genel Tebliğ'e göre 2026 için resmi limit.
        default: return 22_000
        }
    }
    
    private func calculateTax(for baseAmount: Double, year: Int) -> Double {
        if baseAmount <= 0 { return 0 }
        let brackets = getBrackets(for: year)
        var remainingAmount = baseAmount
        var totalTax: Double = 0
        var previousLimit: Double = 0
        
        for bracket in brackets {
            let currentBracketCapacity = bracket.limit - previousLimit
            if remainingAmount > currentBracketCapacity {
                totalTax += currentBracketCapacity * bracket.rate
                remainingAmount -= currentBracketCapacity
                previousLimit = bracket.limit
            } else {
                totalTax += remainingAmount * bracket.rate
                break
            }
        }
        return totalTax
    }
    
    private func getBracketInfo(for baseAmount: Double, year: Int) -> BracketInfo {
        let brackets = getBrackets(for: year)
        var prevLimit: Double = 0
        
        for (index, bracket) in brackets.enumerated() {
            if baseAmount <= bracket.limit {
                let capacity = bracket.limit - prevLimit
                let progress = (baseAmount - prevLimit) / capacity
                let remaining = bracket.limit - baseAmount
                return BracketInfo(rate: Int(bracket.rate * 100), progress: progress, remaining: remaining, bracketIndex: index + 1)
            }
            prevLimit = bracket.limit
        }
        return BracketInfo(rate: 40, progress: 1.0, remaining: 0, bracketIndex: brackets.count)
    }
    
    func calculateSummary(transactions: [TradeTransaction], gains: [RealizedGain], year: Int, isPremium: Bool) -> TaxSummary {
        
        var profitWithShieldTL: Double = 0
        var profitWithoutShieldTL: Double = 0
        var inflationAdvantageTL: Double = 0
        
        let yearGains = gains.filter { Calendar.current.component(.year, from: $0.sellDate) == year }
        
        for gain in yearGains {
            let nominalProfit = gain.profitTL + gain.inflationAdjustmentTL
            var effectiveShieldedProfit = gain.profitTL
            var effectiveAdjustment = gain.inflationAdjustmentTL
            
            // 🚀 KRİTİK DÜZELTME: GVK Mükerrer Madde 81 Kuralı
            if nominalProfit > 0 {
                // Eğer işlem kârlıysa, kalkan kârı en fazla sıfıra indirebilir. Zarar yaratamaz!
                if effectiveShieldedProfit < 0 {
                    effectiveShieldedProfit = 0
                    effectiveAdjustment = nominalProfit // Kalkan sadece kâr kadar uygulandı
                }
            } else {
                // Eğer işlem zaten zararla kapatıldıysa, kanunen Yİ-ÜFE uygulanamaz. Matrahtan direkt düşülür.
                effectiveShieldedProfit = nominalProfit
                effectiveAdjustment = 0
            }
            
            profitWithShieldTL += effectiveShieldedProfit
            profitWithoutShieldTL += nominalProfit
            inflationAdvantageTL += effectiveAdjustment
        }
        
        var dividendTotalTL: Double = 0
        var foreignTaxPaidTL: Double = 0
        var otherIncomeTL: Double = 0
        
        let yearTransactions = transactions.filter { Calendar.current.component(.year, from: $0.date) == year }
        
        for tx in yearTransactions {
            if tx.type == .dividend {
                dividendTotalTL += tx.priceUSD * tx.fxRate
                foreignTaxPaidTL += tx.commissionUSD * tx.fxRate
            } else if tx.type == .other {
                otherIncomeTL += tx.priceUSD * tx.fxRate
            }
        }
        
        let dividendLimit = getDividendDeclarationLimit(for: year)
        var taxableDividend: Double = 0
        var creditableForeignTax: Double = 0
        
        if dividendTotalTL > dividendLimit {
            taxableDividend = dividendTotalTL
            creditableForeignTax = foreignTaxPaidTL
        }
        
        let taxableStockProfit = max(0, isPremium ? profitWithShieldTL : profitWithoutShieldTL)
        let taxBase = taxableStockProfit + taxableDividend + otherIncomeTL
        
        let calculatedTax = calculateTax(for: taxBase, year: year)
        let netTaxToPay = max(0, calculatedTax - creditableForeignTax)
        
        let baseIfPremium = max(0, profitWithShieldTL) + taxableDividend + otherIncomeTL
        let taxIfPremium = calculateTax(for: baseIfPremium, year: year)
        let netTaxIfPremium = max(0, taxIfPremium - creditableForeignTax)
        let potentialTaxSavings = max(0, netTaxToPay - netTaxIfPremium)
        
        let bracketInfo = getBracketInfo(for: taxBase, year: year)
        
        let grossStockProfit = max(0, profitWithoutShieldTL)
        let grossTotalIncome = grossStockProfit + dividendTotalTL + otherIncomeTL
        
        return TaxSummary(
            totalTax: netTaxToPay,
            grossTax: calculatedTax,
            netProfit: isPremium ? profitWithShieldTL : profitWithoutShieldTL,
            grossStockProfit: grossStockProfit,
            grossTotalIncome: grossTotalIncome,
            taxBase: taxBase,
            needsDeclaration: taxBase > 0,
            dividendTotal: dividendTotalTL,
            otherIncome: otherIncomeTL,
            inflationAdvantage: inflationAdvantageTL,
            foreignTaxCredit: creditableForeignTax,
            potentialTaxSavings: potentialTaxSavings,
            bracketInfo: bracketInfo
        )
    }
}
