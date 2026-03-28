import XCTest
@testable import Vergi_Pusulası

@MainActor
final class Vergi_Pusulas_Tests: XCTestCase {

    // MARK: - HELPER (TARİH OLUŞTURUCU)
    private func createDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return Calendar.current.date(from: components) ?? Date()
    }

    // MARK: - 1. FIFO SPLIT TESTİ
    func testFIFOEngineSplitsSellAcrossMultipleBuyLots() throws {
        let buy1 = TradeTransaction(ticker: "AAPL", type: .buy, quantity: 10, priceUSD: 100, date: createDate(year: 2024, month: 1, day: 1), fxRate: 30.0)
        let buy2 = TradeTransaction(ticker: "AAPL", type: .buy, quantity: 5, priceUSD: 110, date: createDate(year: 2024, month: 1, day: 2), fxRate: 30.0)
        let sell = TradeTransaction(ticker: "AAPL", type: .sell, quantity: 12, priceUSD: 120, date: createDate(year: 2024, month: 1, day: 5), fxRate: 30.0)
        
        let gains = FIFOEngine.calculateGains(from: [buy1, buy2, sell])
        
        XCTAssertEqual(gains.count, 2, "Satış işlemi FIFO kuralına göre 2 ayrı lota bölünmeliydi.")
        
        XCTAssertEqual(gains[0].quantity, 10, "İlk parçanın adedi 10 olmalı.")
        XCTAssertEqual(gains[0].buyPriceUSD, 100, "İlk parça doğru maliyete (100$) bağlanmalı.")
        
        XCTAssertEqual(gains[1].quantity, 2, "İkinci parçanın adedi 2 olmalı.")
        XCTAssertEqual(gains[1].buyPriceUSD, 110, "İkinci parça doğru maliyete (110$) bağlanmalı.")
    }

    // MARK: - 2. Yİ-ÜFE KALKANI MATEMATİK TESTİ
    // Not: FIFOEngine veritabanına kapalı olduğu için %10 endeks hesabını mocklayamıyoruz.
    // Bu yüzden kalkanın System (Summary) üzerindeki etkisini test ediyoruz.
    func testYIUFEAdjustmentMathInTaxSummary() throws {
        let gainWithInflation = RealizedGain(ticker: "TSLA", quantity: 10, buyDate: createDate(year: 2022, month: 1, day: 1), sellDate: createDate(year: 2024, month: 1, day: 1), buyPriceUSD: 100, sellPriceUSD: 200, buyFxRate: 30, sellFxRate: 30, profitTL: 30000, inflationAdjustmentTL: 50000)
        
        let summaryWithShield = TaxComputationService.shared.calculateSummary(transactions: [], gains: [gainWithInflation], year: 2024, isPremium: true)
        let summaryWithoutShield = TaxComputationService.shared.calculateSummary(transactions: [], gains: [gainWithInflation], year: 2024, isPremium: false)
        
        XCTAssertEqual(summaryWithShield.netProfit, 30000, "PRO kullanıcıda enflasyon kalkanı net kârı korumalıdır.")
        XCTAssertEqual(summaryWithoutShield.netProfit, 80000, "FREE kullanıcıda enflasyon farkı kâra eklenerek vergi matrahı artırılmalıdır.")
    }

    // MARK: - 3. TEMETTÜ + YURTDIŞI VERGİ TESTİ
    func testDividendSummaryAppliesForeignTaxCredit() throws {
        let dividendTx = TradeTransaction(ticker: "JNJ", type: .dividend, quantity: 1, priceUSD: 1000, commissionUSD: 200, date: createDate(year: 2025, month: 6, day: 1), fxRate: 35.0)
        
        let summary = TaxComputationService.shared.calculateSummary(transactions: [dividendTx], gains: [], year: 2025, isPremium: false)
        
        let expectedGrossTL = 1000.0 * 35.0
        let expectedTaxCreditTL = 200.0 * 35.0
        
        XCTAssertEqual(summary.dividendTotal, expectedGrossTL, "Brüt temettü tutarı (Tutar * Kur) yanlış hesaplandı.")
        XCTAssertEqual(summary.foreignTaxCredit, expectedTaxCreditTL, "Yurtdışında ödenen vergi (Stopaj * Kur) yanlış hesaplandı.")
        
        XCTAssertTrue(summary.totalTax < summary.grossTax, "Stopaj indirimi (Credit) sonrası NET vergi, BRÜT vergiden düşük olmalıdır.")
        XCTAssertEqual(summary.totalTax, max(0, summary.grossTax - summary.foreignTaxCredit), "Net vergi tam olarak brüt vergi eksi stopaj olmalıdır.")
    }

    // MARK: - 4. PRO VS FREE TASARRUF HESAPLAMASI
    func testPremiumUserGetsPotentialTaxSavings() throws {
        let massiveGain = RealizedGain(ticker: "NVDA", quantity: 10, buyDate: createDate(year: 2020, month: 1, day: 1), sellDate: createDate(year: 2024, month: 1, day: 1), buyPriceUSD: 100, sellPriceUSD: 200, buyFxRate: 30, sellFxRate: 30, profitTL: 100000, inflationAdjustmentTL: 400000)
        
        let freeSummary = TaxComputationService.shared.calculateSummary(transactions: [], gains: [massiveGain], year: 2024, isPremium: false)
        let proSummary = TaxComputationService.shared.calculateSummary(transactions: [], gains: [massiveGain], year: 2024, isPremium: true)
        
        XCTAssertTrue(freeSummary.taxBase > proSummary.taxBase, "FREE kullanıcının matrahı, PRO kullanıcıdan BÜYÜK olmalıdır.")
        XCTAssertTrue(freeSummary.totalTax >= proSummary.totalTax, "FREE kullanıcının ödeyeceği vergi, PRO kullanıcıdan YÜKSEK (veya en az eşit) olmalıdır.")
        XCTAssertTrue(freeSummary.potentialTaxSavings > 0, "FREE sisteminde enflasyon kalkanı pazarlaması (savings) 0'dan büyük hesaplanmalıdır.")
    }

    // MARK: - 5. SEÇİLİ YIL FİLTRELEME TESTİ
    func testTaxComputationFiltersBySelectedYear() throws {
        let buy1 = TradeTransaction(ticker: "A", type: .buy, quantity: 1, priceUSD: 100, date: createDate(year: 2023, month: 1, day: 1), fxRate: 20.0)
        let sell2024 = TradeTransaction(ticker: "A", type: .sell, quantity: 1, priceUSD: 150, date: createDate(year: 2024, month: 6, day: 1), fxRate: 30.0)
        
        let buy2 = TradeTransaction(ticker: "B", type: .buy, quantity: 1, priceUSD: 100, date: createDate(year: 2023, month: 1, day: 1), fxRate: 20.0)
        let sell2025 = TradeTransaction(ticker: "B", type: .sell, quantity: 1, priceUSD: 150, date: createDate(year: 2025, month: 6, day: 1), fxRate: 40.0)
        
        let gains = FIFOEngine.calculateGains(from: [buy1, sell2024, buy2, sell2025])
        
        let summary2025 = TaxComputationService.shared.calculateSummary(transactions: [buy1, sell2024, buy2, sell2025], gains: gains, year: 2025, isPremium: false)
        
        // Dinamik Doğrulama: Sadece 2025 yılı kârlarının filtrelendiğinden emin oluyoruz
        let expectedProfitFor2025Only = gains.filter { Calendar.current.component(.year, from: $0.sellDate) == 2025 }.reduce(0) { $0 + $1.profitTL }
        
        XCTAssertEqual(summary2025.netProfit, expectedProfitFor2025Only, "Motor, seçilmeyen yılları tamamen dışarıda bırakmalıdır.")
        XCTAssertTrue(summary2025.netProfit > 0, "Testin doğru çalıştığından emin olmak için filtrelenen kârın 0'dan büyük olduğunu doğruluyoruz.")
    }
}
