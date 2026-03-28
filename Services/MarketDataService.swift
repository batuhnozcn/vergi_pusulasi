import Foundation

class MarketDataService: @unchecked Sendable {
    static let shared = MarketDataService()
    private init() {}
    
    /// Yahoo Finance üzerinden hissenin canlı fiyatını çeker
    func fetchLivePrice(for ticker: String) async -> Double? {
        // Çerez (crumb) istemeyen daha stabil v8 chart API'si
        let urlString = "https://query1.finance.yahoo.com/v8/finance/chart/\(ticker.uppercased())?interval=1d&range=1d"
        guard let url = URL(string: urlString) else { return nil }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }
            
            let decoder = JSONDecoder()
            let responseObj = try decoder.decode(YahooChartResponse.self, from: data)
            return responseObj.chart.result?.first?.meta.regularMarketPrice
        } catch {
            print("Canlı fiyat çekme hatası (\(ticker)): \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - API Veri Modelleri (v8 Chart yapısı)
struct YahooChartResponse: Codable {
    let chart: YahooChartData
}
struct YahooChartData: Codable {
    let result: [YahooChartResult]?
}
struct YahooChartResult: Codable {
    let meta: YahooChartMeta
}
struct YahooChartMeta: Codable {
    let regularMarketPrice: Double?
}
