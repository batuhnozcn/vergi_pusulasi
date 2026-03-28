import SwiftUI
import SwiftData
import Charts
import FirebaseAuth
    
struct AnalysisView: View {
    // 🚀 ÇÖZÜM: Filtreyi RAM'de değil, doğrudan veritabanında yapıyoruz!
        @Query private var userTransactions: [TradeTransaction]
        
        @AppStorage("selectedTaxYear") private var selectedYear = "2026"
        @EnvironmentObject var storeManager: StoreManager
        
        @State private var livePrices: [String: Double] = [:]
        @State private var liveFxRate: Double = 33.50
        @State private var isFetchingData = true
        @State private var showingOpenPositionsSheet = false
        
        init() {
            let currentUserId = Auth.auth().currentUser?.uid ?? ""
            let predicate = #Predicate<TradeTransaction> { $0.userId == currentUserId }
            _userTransactions = Query(filter: predicate, sort: \.date, order: .reverse)
        }
    
    var filteredTransactions: [TradeTransaction] {
            if selectedYear == "Tümü" { return userTransactions }
            return userTransactions.filter { String(Calendar.current.component(.year, from: $0.date)) == selectedYear }
        }
    
    var filteredGains: [RealizedGain] {
        let allGains = FIFOEngine.calculateGains(from: userTransactions)
        if selectedYear == "Tümü" { return allGains }
        return allGains.filter { String(Calendar.current.component(.year, from: $0.sellDate)) == selectedYear }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            Color.clear.frame(height: 0).id("top")
                            
                            HStack {
                                Text("Analiz").font(.system(size: 24, weight: .bold, design: .rounded)).foregroundColor(.primary)
                                Spacer()
                                Menu { Button("Tümü") { selectedYear = "Tümü" }; Button("2026") { selectedYear = "2026" }; Button("2025") { selectedYear = "2025" }; Button("2024") { selectedYear = "2024" }; Button("2023") { selectedYear = "2023" } } label: { HStack(spacing: 6) { Text(selectedYear).font(.system(size: 14, weight: .semibold)); Image(systemName: "chevron.down").font(.system(size: 12, weight: .bold)) }.foregroundColor(Color(hex: "1F5EFF")).padding(.horizontal, 14).padding(.vertical, 8).background(Color(hex: "1F5EFF").opacity(0.1)).clipShape(Capsule()) }
                            }.padding(.horizontal, 24).padding(.top, 16)
                            
                            IncomeDistributionCard(transactions: filteredTransactions, gains: filteredGains, selectedYear: selectedYear, isPremium: storeManager.isPremium)
                            
                            TaxLossHarvestingCard(transactions: userTransactions, livePrices: livePrices, liveFxRate: liveFxRate)
                            
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                showingOpenPositionsSheet = true
                            }) {
                                MacroSimulationCard(transactions: userTransactions, livePrices: livePrices, liveFxRate: liveFxRate, selectedYear: selectedYear, isFetching: isFetchingData, isPremium: storeManager.isPremium)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            TaxTipCard()
                            
                            Spacer(minLength: 24)
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ScrollToTop"))) { notif in
                        if let tab = notif.object as? Int, tab == 1 { withAnimation { proxy.scrollTo("top", anchor: .top) } }
                    }
                }
            }
            .sheet(isPresented: $showingOpenPositionsSheet) {
                OpenPositionsListView(transactions: userTransactions, livePrices: livePrices, liveFxRate: liveFxRate, isPremium: storeManager.isPremium)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .task { await fetchLiveMarketData() }
    }
    
    private func fetchLiveMarketData() async {
        let openPositions = FIFOEngine.calculateOpenPositions(from: userTransactions)
        if let fx = await TCMBService.shared.fetchRate(for: Date()) { await MainActor.run { self.liveFxRate = fx } }
        for position in openPositions {
            if let price = await MarketDataService.shared.fetchLivePrice(for: position.ticker) {
                await MainActor.run { self.livePrices[position.ticker] = price }
            }
        }
        await MainActor.run { self.isFetchingData = false }
    }
}

// MARK: - ALT BİLEŞENLER
struct IncomeDistributionCard: View {
    let transactions: [TradeTransaction]; let gains: [RealizedGain]; let selectedYear: String; let isPremium: Bool
    
    var body: some View {
        let numericYear = Int(selectedYear) ?? Calendar.current.component(.year, from: Date())
        let summary = TaxComputationService.shared.calculateSummary(transactions: transactions, gains: gains, year: numericYear, isPremium: isPremium)
        
        let stockProfit = summary.grossStockProfit
        let dividendProfit = summary.dividendTotal
        let otherProfit = summary.otherIncome
        let totalIncome = summary.grossTotalIncome
        
        let stockColor = Color(hex: "2954C8"); let dividendColor = Color(hex: "46B978"); let otherColor = Color(hex: "F0A528")
        
        return VStack(spacing: 24) { HStack { Text("Gelir Dağılımı").font(.system(size: 18, weight: .bold)); Spacer(); Text("\(selectedYear) Yılı").font(.system(size: 13)).foregroundColor(.secondary) }; ZStack { Chart { if stockProfit > 0 { SectorMark(angle: .value("Hisse", stockProfit), innerRadius: .ratio(0.75), angularInset: 2).foregroundStyle(stockColor).cornerRadius(6) }; if dividendProfit > 0 { SectorMark(angle: .value("Temettü", dividendProfit), innerRadius: .ratio(0.75), angularInset: 2).foregroundStyle(dividendColor).cornerRadius(6) }; if otherProfit > 0 { SectorMark(angle: .value("Diğer", otherProfit), innerRadius: .ratio(0.75), angularInset: 2).foregroundStyle(otherColor).cornerRadius(6) }; if totalIncome == 0 { SectorMark(angle: .value("Boş", 1), innerRadius: .ratio(0.75), angularInset: 0).foregroundStyle(Color.gray.opacity(0.1)) } }.frame(height: 220); VStack(spacing: 4) { Text("TOPLAM GELİR").font(.system(size: 11, weight: .bold)).foregroundColor(.secondary); Text(totalIncome > 0 ? formatCompact(totalIncome) : "₺0").font(.system(size: 28, weight: .bold, design: .rounded)).foregroundColor(.primary) } }.padding(.vertical, 10); VStack(spacing: 16) { DistributionRow(color: stockColor, title: "Hisse Satışı", amount: stockProfit, total: totalIncome); DistributionRow(color: dividendColor, title: "Temettü", amount: dividendProfit, total: totalIncome); DistributionRow(color: otherColor, title: "Diğer Gelirler", amount: otherProfit, total: totalIncome) } }.padding(24).background(Color(UIColor.secondarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 24)).shadow(color: .black.opacity(0.02), radius: 10, y: 4).padding(.horizontal, 24)
    }
    private func formatCompact(_ value: Double) -> String { value >= 1000 ? String(format: "₺%.1fK", value / 1000) : String(format: "₺%.0f", value) }
}

struct DistributionRow: View { let color: Color; let title: String; let amount: Double; let total: Double; var body: some View { HStack { Circle().fill(color).frame(width: 12, height: 12); Text(title).font(.system(size: 15, weight: .medium)).foregroundColor(.primary); Spacer(); VStack(alignment: .trailing, spacing: 2) { Text(formatCurrency(amount)).font(.system(size: 15, weight: .bold)).foregroundColor(.primary); let percentage = total > 0 ? (amount / total) * 100 : 0; Text("%\(String(format: "%.0f", percentage))").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary) } } }; private func formatCurrency(_ value: Double) -> String { let f = NumberFormatter(); f.numberStyle = .currency; f.currencySymbol = "₺"; f.maximumFractionDigits = 0; return f.string(from: NSNumber(value: value)) ?? "₺0" } }

struct TaxLossHarvestingCard: View {
    let transactions: [TradeTransaction]; let livePrices: [String: Double]; let liveFxRate: Double; let marginalTaxRate = 0.20
    var lossPositions: [(ticker: String, unrealizedLossTL: Double, taxAdvantageTL: Double)] { let openPos = FIFOEngine.calculateOpenPositions(from: transactions); var results: [(String, Double, Double)] = []; for pos in openPos { if let currentPrice = livePrices[pos.ticker], currentPrice < pos.averageCostUSD { let lossUSD = (pos.averageCostUSD - currentPrice) * pos.totalQuantity; let lossTL = lossUSD * liveFxRate; let advantageTL = lossTL * marginalTaxRate; if lossTL > 0 { results.append((pos.ticker, lossTL, advantageTL)) } } }; return results.sorted { $0.1 > $1.1 } }
    var body: some View { VStack(alignment: .leading, spacing: 16) { HStack { Text("Zarar Realizasyonu Fırsatları").font(.system(size: 16, weight: .bold)); Spacer(); Image(systemName: "arrow.down.right.circle.fill").foregroundColor(.red.opacity(0.8)) }; if lossPositions.isEmpty { VStack(spacing: 12) { Image(systemName: "checkmark.shield.fill").font(.system(size: 32)).foregroundColor(.green.opacity(0.5)); Text("Harika!").font(.system(size: 15, weight: .bold)).foregroundColor(.primary); Text("Şu an zararda olan bir açık pozisyonunuz bulunmuyor.").font(.system(size: 12)).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal, 8) }.padding(.vertical, 20).frame(maxWidth: .infinity).background(Color(UIColor.systemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 16)) } else { VStack(spacing: 12) { ForEach(lossPositions.prefix(3), id: \.ticker) { item in HStack(spacing: 12) { Circle().fill(Color(UIColor.systemGroupedBackground)).frame(width: 40, height: 40).overlay(Text(item.ticker.prefix(1)).font(.system(size: 14, weight: .bold))); VStack(alignment: .leading, spacing: 2) { Text(item.ticker).font(.system(size: 15, weight: .bold)); Text("-\(formatCurrency(item.unrealizedLossTL)) Zarar").font(.system(size: 11, weight: .medium)).foregroundColor(.red) }; Spacer(); VStack(alignment: .trailing, spacing: 2) { Text("VERGİ AVANTAJI").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary); Text("+\(formatCurrency(item.taxAdvantageTL))").font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(.green) } }.padding(12).background(Color(UIColor.systemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 16)) } }; Text("*Bu hisseleri satarak kârınızdan düşebilir ve tahmini verginizi azaltabilirsiniz.").font(.system(size: 10, weight: .light)).italic().foregroundColor(.secondary) } }.padding(24).background(Color(UIColor.secondarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 24)).shadow(color: .black.opacity(0.02), radius: 10, y: 4).padding(.horizontal, 24) }; private func formatCurrency(_ value: Double) -> String { let f = NumberFormatter(); f.numberStyle = .currency; f.currencySymbol = "₺"; f.maximumFractionDigits = 0; return f.string(from: NSNumber(value: value)) ?? "₺0" }
}

struct TaxTipCard: View { var body: some View { HStack(alignment: .top, spacing: 16) { Circle().fill(Color(UIColor.secondarySystemGroupedBackground)).frame(width: 32, height: 32).overlay(Image(systemName: "lightbulb.fill").foregroundColor(Color(hex: "2954C8")).font(.system(size: 14))).shadow(color: .black.opacity(0.05), radius: 2, y: 1); VStack(alignment: .leading, spacing: 6) { Text("Vergi İpucu").font(.system(size: 14, weight: .bold)).foregroundColor(.primary); Text("Bazı senaryolarda satış zamanlaması ve elde tutma süresi, tahmini vergi yükünüzü değiştirebilir. Kesin yorum için mali müşavirinize danışın.").font(.system(size: 12)).foregroundColor(.secondary).lineSpacing(3) } }.padding(20).background(Color(hex: "EDF2FA").opacity(UITraitCollection.current.userInterfaceStyle == .dark ? 0.1 : 1.0)).clipShape(RoundedRectangle(cornerRadius: 16)).padding(.horizontal, 24) } }

struct MacroSimulationCard: View {
    let transactions: [TradeTransaction]; let livePrices: [String: Double]; let liveFxRate: Double; let selectedYear: String; let isFetching: Bool; let isPremium: Bool
    
    var currentTax: Double {
        let targetYear = Int(selectedYear) ?? Calendar.current.component(.year, from: Date())
        let gains = FIFOEngine.calculateGains(from: transactions)
        let summary = TaxComputationService.shared.calculateSummary(transactions: transactions, gains: gains, year: targetYear, isPremium: isPremium)
        return summary.grossTax
    }
    
    var totalSimulatedTax: Double {
        var tempTransactions = transactions
        let openPos = FIFOEngine.calculateOpenPositions(from: tempTransactions)
        
        for pos in openPos {
            let price = livePrices[pos.ticker] ?? pos.averageCostUSD
            let shadowSell = TradeTransaction(ticker: pos.ticker, type: .sell, quantity: pos.totalQuantity, priceUSD: price, commissionUSD: 0, date: Date(), fxRate: liveFxRate)
            tempTransactions.append(shadowSell)
        }
        
        let newGains = FIFOEngine.calculateGains(from: tempTransactions)
        let targetYear = Int(selectedYear) ?? Calendar.current.component(.year, from: Date())
        let summary = TaxComputationService.shared.calculateSummary(transactions: tempTransactions, gains: newGains, year: targetYear, isPremium: isPremium)
        return summary.grossTax
    }
    
    var body: some View { VStack(alignment: .leading, spacing: 20) { HStack { Image(systemName: "chart.pie.fill").font(.system(size: 18, weight: .bold)); Text("Açık Pozisyon Simülasyonu").font(.system(size: 18, weight: .bold)); Spacer(); if isFetching { ProgressView().tint(.white) } else { Image(systemName: "chevron.right").font(.system(size: 16, weight: .bold)) } }.foregroundColor(.white); Text("Eğer bugün tüm pozisyonlarınızı kapatsaydınız oluşacak tahmini vergi yükümlülüğünüz:").font(.system(size: 13)).foregroundColor(.white.opacity(0.8)).lineSpacing(4); HStack(alignment: .firstTextBaseline, spacing: 8) { Text(formatCurrency(totalSimulatedTax)).font(.system(size: 36, weight: .heavy, design: .rounded)).foregroundColor(.white); Text("Tahmini Vergi").font(.system(size: 12)).foregroundColor(.white.opacity(0.6)) }; VStack(spacing: 8) { let progress = totalSimulatedTax > 0 ? (currentTax / totalSimulatedTax) : 0; GeometryReader { geo in ZStack(alignment: .leading) { Capsule().frame(height: 6).foregroundColor(Color.white.opacity(0.15)); Capsule().frame(width: max(0, geo.size.width * CGFloat(progress)), height: 6).foregroundColor(Color(hex: "1F5EFF")) } }.frame(height: 6); HStack { Text("GERÇEKLEŞEN: \(formatCurrency(currentTax))").font(.system(size: 10, weight: .bold)).foregroundColor(.white.opacity(0.6)); Spacer(); let diff = max(0, totalSimulatedTax - currentTax); Text("KALAN: \(formatCurrency(diff))").font(.system(size: 10, weight: .bold)).foregroundColor(.white.opacity(0.6)) } } }.padding(24).background(Color(hex: "0D1425")).clipShape(RoundedRectangle(cornerRadius: 24)).shadow(color: Color(hex: "0D1425").opacity(0.2), radius: 15, y: 8).padding(.horizontal, 24) }; private func formatCurrency(_ value: Double) -> String { let f = NumberFormatter(); f.numberStyle = .currency; f.currencySymbol = "₺"; f.maximumFractionDigits = 0; return f.string(from: NSNumber(value: value)) ?? "₺0" }
}

struct OpenPositionsListView: View {
    let transactions: [TradeTransaction]; let livePrices: [String: Double]; let liveFxRate: Double; let isPremium: Bool
    @Environment(\.dismiss) private var dismiss; @State private var selectedPosition: OpenPosition? = nil
    var openPositions: [OpenPosition] { FIFOEngine.calculateOpenPositions(from: transactions) }
    var body: some View { NavigationStack { List { if openPositions.isEmpty { Text("Aktif açık pozisyonunuz bulunmuyor.").foregroundColor(.secondary).listRowBackground(Color.clear) } else { Section { ForEach(openPositions) { pos in Button(action: { selectedPosition = pos }) { OpenPositionRow(position: pos, livePrice: livePrices[pos.ticker], liveFxRate: liveFxRate, transactions: transactions, isPremium: isPremium) }.buttonStyle(PlainButtonStyle()) } }; Section { Text("Not: Listedeki tekil vergi etkilerinin toplamı, makro tahmini vergiye eşit olmayabilir.").font(.system(size: 11)).foregroundColor(.secondary).listRowBackground(Color.clear) } } }.navigationTitle("Açık Pozisyonlar").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Kapat") { dismiss() } } }.sheet(item: $selectedPosition) { pos in SimulationSheetView(position: pos, allTransactions: transactions) } } }
}

struct OpenPositionRow: View {
    let position: OpenPosition; let livePrice: Double?; let liveFxRate: Double; let transactions: [TradeTransaction]; let isPremium: Bool
    var body: some View {
        let currentPrice = livePrice ?? position.averageCostUSD; let totalCost = position.totalQuantity * position.averageCostUSD; let currentValue = position.totalQuantity * currentPrice; let profitUSD = currentValue - totalCost; let profitPct = totalCost > 0 ? (profitUSD / totalCost) * 100 : 0; let isProfit = profitUSD >= 0; let taxImpact = calculateSingleTaxImpact(for: position, simulatedPrice: currentPrice)
        VStack(alignment: .leading, spacing: 10) { HStack(alignment: .center, spacing: 12) { VStack(alignment: .leading, spacing: 4) { Text(position.ticker).font(.system(size: 16, weight: .bold)); Text("\(String(format: "%.2f", position.totalQuantity)) Adet • Mal: $\(String(format: "%.2f", position.averageCostUSD))").font(.system(size: 12)).foregroundColor(.secondary) }; Spacer(); VStack(alignment: .trailing, spacing: 4) { Text("$\(String(format: "%.2f", currentPrice))").font(.system(size: 15, weight: .bold, design: .rounded)); Text("\(isProfit ? "+" : "") $\(String(format: "%.2f", profitUSD)) (\(isProfit ? "+" : "")%\(String(format: "%.2f", abs(profitPct))))").font(.system(size: 11, weight: .bold)).foregroundColor(isProfit ? .green : .red) } }; Divider(); HStack { Text("Tek Başına Satılırsa Vergi Etkisi:").font(.system(size: 12, weight: .medium)).foregroundColor(.secondary); Spacer(); Text(taxImpact > 0 ? "+\(formatCurrency(taxImpact))" : formatCurrency(taxImpact)).font(.system(size: 13, weight: .bold)).foregroundColor(taxImpact > 0 ? .red : (taxImpact < 0 ? .green : .primary)) } }.padding(.vertical, 4)
    }
    
    private func calculateSingleTaxImpact(for position: OpenPosition, simulatedPrice: Double) -> Double {
        let targetYear = Calendar.current.component(.year, from: Date())
        
        let currentGains = FIFOEngine.calculateGains(from: transactions)
        let currentSummary = TaxComputationService.shared.calculateSummary(transactions: transactions, gains: currentGains, year: targetYear, isPremium: isPremium)
        let currentTax = currentSummary.grossTax
        
        var tempTransactions = transactions
        let shadowSell = TradeTransaction(ticker: position.ticker, type: .sell, quantity: position.totalQuantity, priceUSD: simulatedPrice, commissionUSD: 0, date: Date(), fxRate: liveFxRate)
        tempTransactions.append(shadowSell)
        
        let newGains = FIFOEngine.calculateGains(from: tempTransactions)
        let newSummary = TaxComputationService.shared.calculateSummary(transactions: tempTransactions, gains: newGains, year: targetYear, isPremium: isPremium)
        let newTax = newSummary.grossTax
        
        return newTax - currentTax
    }
    private func formatCurrency(_ value: Double) -> String { let f = NumberFormatter(); f.numberStyle = .currency; f.currencySymbol = "₺"; f.maximumFractionDigits = 0; return f.string(from: NSNumber(value: value)) ?? "₺0" }
}
