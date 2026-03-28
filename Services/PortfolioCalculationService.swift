import Foundation

class PortfolioCalculationService {
    static let shared = PortfolioCalculationService()
    
    private var cachedGains: [RealizedGain] = []
    private var lastHash: String = ""
    
    private init() {}
    
    func calculateGains(from transactions: [TradeTransaction]) -> [RealizedGain] {
        // Eğer hiç işlem yoksa boş dön ve motoru yorma
        guard !transactions.isEmpty else { return [] }
        
        // İşlemlerin bir "parmak izini" çıkarıyoruz:
        // Toplam işlem adedi ve en son güncellenen kaydın zaman damgası
        let latestUpdate = transactions.map { $0.updatedAt.timeIntervalSince1970 }.max() ?? 0
        let currentHash = "\(transactions.count)_\(latestUpdate)"
        
        // Parmak izi değişmediyse (yeni işlem eklenmedi/silinmedi/düzenlenmediyse) cache'den ver
        if currentHash == lastHash && !cachedGains.isEmpty {
            return cachedGains
        }
        
        // Değişiklik varsa motoru çalıştır, hesapla ve hafızaya (cache) mühürle
        let calculated = FIFOEngine.calculateGains(from: transactions)
        self.cachedGains = calculated
        self.lastHash = currentHash
        
        return calculated
    }
    
    // Gerekirse hafızayı manuel temizlemek için
    func clearCache() {
        cachedGains = []
        lastHash = ""
    }
}
