import Foundation

// 🚨 YENİ ÇÖZÜM (Madde 5): Concurrency (Eşzamanlılık) sorunlarını önlemek için XML ayrıştırıcı tamamen izole edildi.
class TCMBXMLParser: NSObject, XMLParserDelegate {
    private var currentForexBuying = ""
    private var isUSD = false
    private var parsedRate: Double?
    
    func parse(data: Data) -> Double? {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return parsedRate
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "Currency" { isUSD = (attributeDict["CurrencyCode"] == "USD") }
        if isUSD && elementName == "ForexBuying" { currentForexBuying = "" }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isUSD { currentForexBuying += string }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if isUSD && elementName == "ForexBuying" {
            // Virgül ihtimaline karşı güvenli parse (Ek validasyon)
            let cleanString = currentForexBuying.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
            if let rate = Double(cleanString) { self.parsedRate = rate }
            isUSD = false
        }
    }
}

class TCMBService: @unchecked Sendable {
    static let shared = TCMBService()
    private let cacheDefaults = UserDefaults.standard
    
    private init() {}
    
    /// Toplu işlemler için kurları önceden cache'e alır
    func preFetchRates(for dates: [Date]) async {
        let uniqueDates = Set(dates.map { Calendar.current.startOfDay(for: $0) })
        await withTaskGroup(of: Void.self) { group in
            for date in uniqueDates {
                group.addTask { _ = await self.fetchRate(for: date) }
            }
        }
    }
    
    // 🚀 YENİ: VERGİ KANUNU T-1 KURALI İÇİN ÖZEL FONKSİYON
    /// Vergi kanunu ve Midas raporu gereği, alım-satım işlemlerinin maliyet hesaplamasında T-1 (bir önceki günün) kuru kullanılır.
    /// Veritabanına yeni bir işlem (TradeTransaction) kaydederken doğrudan bu fonksiyonu çağıracağız.
    func fetchTransactionRate(for date: Date) async -> Double? {
        // İşlem tarihinden tam 1 gün öncesini (T-1) hesapla
        guard let tMinusOne = Calendar.current.date(byAdding: .day, value: -1, to: date) else { return nil }
        return await fetchRate(for: tMinusOne)
    }
    
    /// Ana sayfadaki anlık gösterimler veya canlı simülasyonlar için standart güncel kur çağrısı (T-0)
    func fetchRate(for date: Date) async -> Double? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateKey = formatter.string(from: date)
        let cacheKey = "TCMB_USD_\(dateKey)"
        
        if let cachedRate = cacheDefaults.value(forKey: cacheKey) as? Double {
            return cachedRate
        }
        
        return await fetchFromAPIWithFallback(date: date, originalDateKey: cacheKey, attemptsLeft: 7)
    }
    
    private func fetchFromAPIWithFallback(date: Date, originalDateKey: String, attemptsLeft: Int) async -> Double? {
        if attemptsLeft == 0 { return nil }
        
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(date)
        
        let urlString: String
        if isToday {
            urlString = "https://www.tcmb.gov.tr/kurlar/today.xml"
        } else {
            let year = calendar.component(.year, from: date)
            let month = String(format: "%02d", calendar.component(.month, from: date))
            let day = String(format: "%02d", calendar.component(.day, from: date))
            urlString = "https://www.tcmb.gov.tr/kurlar/\(year)\(month)/\(day)\(month)\(year).xml"
        }
        
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            // 🚨 YENİ ÇÖZÜM: Her istek kendi bağımsız izole parser nesnesini yaratır
            let parser = TCMBXMLParser()
            if let rate = parser.parse(data: data) {
                cacheDefaults.set(rate, forKey: originalDateKey)
                return rate
            } else {
                return await fetchPreviousDay(date: date, originalDateKey: originalDateKey, attemptsLeft: attemptsLeft)
            }
        } catch {
            return await fetchPreviousDay(date: date, originalDateKey: originalDateKey, attemptsLeft: attemptsLeft)
        }
    }
    
    private func fetchPreviousDay(date: Date, originalDateKey: String, attemptsLeft: Int) async -> Double? {
        guard let previousDate = Calendar.current.date(byAdding: .day, value: -1, to: date) else { return nil }
        return await fetchFromAPIWithFallback(date: previousDate, originalDateKey: originalDateKey, attemptsLeft: attemptsLeft - 1)
    }
}
