import SwiftUI
import SwiftData
import FirebaseAuth

struct GroupedGain: Identifiable {
    var id: String { "\(ticker)_\(sellDate.timeIntervalSince1970)" }
    let ticker: String
    let sellDate: Date
    let totalProfitTL: Double
    let totalProfitUSD: Double
    let sellFxRate: Double
}

struct ReportsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TradeTransaction.date, order: .reverse) private var items: [TradeTransaction]
    
    @EnvironmentObject var storeManager: StoreManager
    @AppStorage("selectedTaxYear") private var selectedYear = "2026"
    
    @State private var navPath = NavigationPath()
    @State private var showPaywall = false
    
    var userItems: [TradeTransaction] {
        let currentUserId = Auth.auth().currentUser?.uid ?? ""
        return items.filter { $0.userId == currentUserId }
    }
    
    var filteredIncomeItems: [TradeTransaction] {
        let incomeTxs = userItems.filter { $0.type == .dividend || $0.type == .other }
        if selectedYear == "Tümü" { return incomeTxs }
        return incomeTxs.filter { String(Calendar.current.component(.year, from: $0.date)) == selectedYear }
    }
    
    // 1. GERÇEK KÂRLAR (Yİ-ÜFE Motorundan Çıkan Hal)
    var filteredGains: [RealizedGain] {
        let allGains = PortfolioCalculationService.shared.calculateGains(from: userItems)
        if selectedYear == "Tümü" { return allGains }
        return allGains.filter { String(Calendar.current.component(.year, from: $0.sellDate)) == selectedYear }
    }
    
    // 2. NOMİNAL KÂRLAR (Cepteki Para - HİÇBİR ZAMAN AZALMAZ)
    var nominalGains: [RealizedGain] {
        return filteredGains.map { gain in
            var newGain = gain
            newGain.profitTL = gain.profitTL + gain.inflationAdjustmentTL
            newGain.inflationAdjustmentTL = 0
            return newGain
        }
    }
    
    // 3. DEVLETE BİLDİRİLEN MATRAH (Sistem PRO ise otomatik Yİ-ÜFE uygular)
        var activeGains: [RealizedGain] {
            let baseGains = storeManager.isPremium ? filteredGains : nominalGains
            
            // 🚀 DÜZELTME: Arayüzdeki listeyi TSLA gibi eksi rakamlardan koruyan Gölge Zarar Zırhı!
            return baseGains.map { gain in
                let nominalProfit = gain.profitTL + gain.inflationAdjustmentTL
                var effectiveShieldedProfit = gain.profitTL
                var effectiveAdjustment = gain.inflationAdjustmentTL
                
                if nominalProfit > 0 {
                    if effectiveShieldedProfit < 0 {
                        effectiveShieldedProfit = 0
                        effectiveAdjustment = nominalProfit
                    }
                } else {
                    effectiveShieldedProfit = nominalProfit
                    effectiveAdjustment = 0
                }
                
                var newGain = gain
                newGain.profitTL = effectiveShieldedProfit
                newGain.inflationAdjustmentTL = effectiveAdjustment
                return newGain
            }
        }
    
    // 4. EKRANDAKİ HİSSE LİSTESİ (HER ZAMAN CEPTEKİ PARAYI GÖSTERİR!)
        var groupedGains: [GroupedGain] {
            var grouped: [String: [RealizedGain]] = [:]
            
            // 🚀 DÜZELTME: Önceden 'nominalGains' yazıyordu. Artık PRO ise kalkanlı (activeGains), değilse ham kârları gösterecek!
            for gain in activeGains {
                let key = "\(gain.ticker)_\(gain.sellDate.timeIntervalSince1970)"
                grouped[key, default: []].append(gain)
            }
            
            var result: [GroupedGain] = []
            for (_, gains) in grouped {
                guard let first = gains.first else { continue }
                let totalTL: Double = gains.reduce(0.0) { $0 + $1.profitTL }
                let totalUSD: Double = gains.reduce(0.0) { partialResult, gain in
                    let usdProfit = (gain.sellPriceUSD - gain.buyPriceUSD) * gain.quantity
                    return partialResult + usdProfit
                }
                result.append(GroupedGain(ticker: first.ticker, sellDate: first.sellDate, totalProfitTL: totalTL, totalProfitUSD: totalUSD, sellFxRate: first.sellFxRate))
            }
            return result.sorted { $0.sellDate > $1.sellDate }
        }
    
    var body: some View {
        NavigationStack(path: $navPath) {
            ZStack {
                Color(hex: "F4F6F9").ignoresSafeArea()
                
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            Color.clear.frame(height: 0).id("top")
                            
                            headerView
                            summaryCardsView
                            yiufeBadgeSection
                            stockSalesSection
                            dividendSection
                            otherIncomeSection
                            // 🚀 DÜZELTME: Kafa karıştıran o alt özet tablosu (finalCalculationView) tamamen silindi!
                            pdfButton
                            
                            Spacer(minLength: 40)
                        }
                    }
                    .navigationDestination(for: String.self) { value in
                        if value == "ResultSummary" { ResultSummaryView() }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ScrollToTop"))) { notif in
                        if let tab = notif.object as? Int, tab == 3 {
                            navPath = NavigationPath()
                            withAnimation { proxy.scrollTo("top", anchor: .top) }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }
    
    private var headerView: some View {
        HStack {
            Text("Vergi Raporu").font(.system(size: 24, weight: .bold, design: .rounded)).foregroundColor(.primary)
            Spacer()
            if !storeManager.isPremium {
                Button(action: { UIImpactFeedbackGenerator(style: .light).impactOccurred(); showPaywall = true }) {
                    Text("PRO").font(.system(size: 12, weight: .heavy, design: .rounded)).padding(.horizontal, 12).padding(.vertical, 6).background(Color(hex: "1072EB")).foregroundColor(.white).clipShape(Capsule()).shadow(color: Color(hex: "1072EB").opacity(0.3), radius: 5, y: 2)
                }.padding(.trailing, 4)
            }
            Menu {
                Button("Tümü") { selectedYear = "Tümü" }; Button("2026") { selectedYear = "2026" }; Button("2025") { selectedYear = "2025" }; Button("2024") { selectedYear = "2024" }; Button("2023") { selectedYear = "2023" }
            } label: {
                HStack(spacing: 6) { Text(selectedYear).font(.system(size: 14, weight: .semibold)); Image(systemName: "chevron.down").font(.system(size: 12, weight: .bold)) }.foregroundColor(Color(hex: "1072EB")).padding(.horizontal, 14).padding(.vertical, 8).background(Color(hex: "1072EB").opacity(0.1)).clipShape(Capsule())
            }
        }.padding(.horizontal, 24).padding(.top, 16)
    }
    
    private var summaryCardsView: some View {
        let yearInt = Int(selectedYear) ?? Calendar.current.component(.year, from: Date())
        let summary = TaxComputationService.shared.calculateSummary(transactions: userItems, gains: activeGains, year: yearInt, isPremium: storeManager.isPremium)
        
        return VStack(alignment: .leading, spacing: 20) {
            HStack { Text("Toplam Gelir (Brüt)").font(.system(size: 14, weight: .medium)).foregroundColor(.white.opacity(0.9)); Spacer(); Image(systemName: "wallet.pass.fill").font(.system(size: 20)).foregroundColor(.white.opacity(0.8)) }
            Text(formatCurrency(summary.grossTotalIncome)).font(.system(size: 36, weight: .bold, design: .rounded)).foregroundColor(.white)
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) { Text("Vergi Matrahı").font(.system(size: 12)).foregroundColor(.white.opacity(0.8)); Text(formatCurrency(summary.taxBase)).font(.system(size: 16, weight: .semibold)).foregroundColor(.white) }.frame(maxWidth: .infinity, alignment: .leading).padding(12).background(Color.white.opacity(0.15)).clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 6) { Text("Tahmini Vergi").font(.system(size: 12)).foregroundColor(.white.opacity(0.8)); Text(formatCurrency(summary.totalTax)).font(.system(size: 16, weight: .semibold)).foregroundColor(.white) }.frame(maxWidth: .infinity, alignment: .leading).padding(12).background(Color.white.opacity(0.15)).clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(24).background(Color(hex: "1072EB")).clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous)).shadow(color: Color(hex: "1072EB").opacity(0.3), radius: 15, y: 8).padding(.horizontal, 24)
    }
    
    private var yiufeBadgeSection: some View {
        let yearInt = Int(selectedYear) ?? Calendar.current.component(.year, from: Date())
        let summary = TaxComputationService.shared.calculateSummary(transactions: userItems, gains: activeGains, year: yearInt, isPremium: storeManager.isPremium)
        let adjustment = summary.inflationAdvantage
        
        return VStack {
            if storeManager.isPremium {
                if adjustment > 0 {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.shield.fill").foregroundColor(.green).font(.system(size: 24))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("👑 PRO Avantajı Devrede").font(.system(size: 14, weight: .bold)).foregroundColor(.green)
                            Text("Yİ-ÜFE kalkanı otomatik uygulandı. Matrahınızdan \(formatCurrency(adjustment)) yasal indirim sağlandı.").font(.system(size: 12)).foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.green.opacity(0.2), lineWidth: 1))
                    .padding(.horizontal, 24)
                }
            } else {
                Button(action: { UIImpactFeedbackGenerator(style: .medium).impactOccurred(); showPaywall = true }) {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: "lock.shield.fill").foregroundColor(Color(hex: "1072EB")).font(.system(size: 24))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Yİ-ÜFE Kalkanı (PRO)").font(.system(size: 14, weight: .bold)).foregroundColor(.primary)
                            Text("Enflasyon endekslemesi ile vergi matrahınızı yasal olarak düşürmek için PRO'ya geçin.").font(.system(size: 12)).foregroundColor(.secondary).multilineTextAlignment(.leading)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundColor(.secondary).font(.system(size: 14))
                    }
                    .padding(16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.1), lineWidth: 1))
                    .padding(.horizontal, 24)
                }
            }
        }
    }
    
    private var stockSalesSection: some View { StitchSection(title: "HİSSE SATIŞ KÂRI") { if groupedGains.isEmpty { EmptyReportRow(message: "Kayıtlı hisse işlemi yok.") } else { VStack(spacing: 0) { ForEach(Array(groupedGains.enumerated()), id: \.element.id) { index, group in StitchReportRow(isTicker: true, iconText: String(group.ticker.prefix(4)), title: "\(group.ticker) Satış", subtitle: "$\(String(format: "%.2f", group.totalProfitUSD)) • Kur: \(String(format: "%.2f", group.sellFxRate))", amount: group.totalProfitTL); if index < groupedGains.count - 1 { Divider().padding(.leading, 76) } } }.background(Color.white).clipShape(RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.1), lineWidth: 1)) } } }
    
    private var dividendSection: some View { let dividendItems = filteredIncomeItems.filter { $0.type == .dividend }; return StitchSection(title: "TEMETTÜ GELİRLERİ") { if dividendItems.isEmpty { EmptyReportRow(message: "Kayıtlı temettü işlemi yok.") } else { VStack(spacing: 0) { ForEach(Array(dividendItems.enumerated()), id: \.element.id) { index, item in StitchReportRow(isTicker: false, iconName: "banknote.fill", iconColor: Color(hex: "1072EB"), title: "\(item.ticker) Temettü", subtitle: "$\(String(format: "%.2f", item.priceUSD)) • Kur: \(String(format: "%.2f", item.fxRate))", amount: item.priceUSD * item.fxRate); if index < dividendItems.count - 1 { Divider().padding(.leading, 76) } } }.background(Color.white).clipShape(RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.1), lineWidth: 1)) } } }
    
    private var otherIncomeSection: some View { let otherItems = filteredIncomeItems.filter { $0.type == .other }; return StitchSection(title: "DİĞER GELİRLER") { if otherItems.isEmpty { EmptyReportRow(message: "Kayıtlı diğer gelir yok.") } else { VStack(spacing: 0) { ForEach(Array(otherItems.enumerated()), id: \.element.id) { index, item in StitchReportRow(isTicker: false, iconName: "bag.fill", iconColor: .purple, title: item.ticker.isEmpty ? "Diğer Gelir" : item.ticker, subtitle: "$\(String(format: "%.2f", item.priceUSD)) • Kur: \(String(format: "%.2f", item.fxRate))", amount: item.priceUSD * item.fxRate); if index < otherItems.count - 1 { Divider().padding(.leading, 76) } } }.background(Color.white).clipShape(RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.1), lineWidth: 1)) } } }
    
    private var pdfButton: some View { Button(action: { if storeManager.isPremium { navPath.append("ResultSummary") } else { UIImpactFeedbackGenerator(style: .medium).impactOccurred(); showPaywall = true } }) { HStack { Image(systemName: "doc.text.fill").font(.system(size: 18)); Text("PDF Raporu Oluştur").font(.system(size: 16, weight: .bold)); if !storeManager.isPremium { Spacer(); Image(systemName: "lock.fill").font(.system(size: 14)).foregroundColor(.white.opacity(0.8)) } }.foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 16).padding(.horizontal, !storeManager.isPremium ? 20 : 0).background(Color(hex: "1072EB")).clipShape(RoundedRectangle(cornerRadius: 16)).shadow(color: Color(hex: "1072EB").opacity(0.3), radius: 10, y: 5) }.padding(.horizontal, 24).padding(.top, 8) }
    
    private func formatCurrency(_ value: Double, showSign: Bool = false) -> String { let f = NumberFormatter(); f.numberStyle = .currency; f.currencySymbol = "₺"; f.maximumFractionDigits = 2; let s = f.string(from: NSNumber(value: abs(value))) ?? "₺0.00"; if showSign { return value > 0 ? "+\(s)" : (value < 0 ? "-\(s)" : s) }; return s }
}

struct StitchSection<Content: View>: View { let title: String; let content: Content; init(title: String, @ViewBuilder content: () -> Content) { self.title = title; self.content = content() }; var body: some View { VStack(alignment: .leading, spacing: 12) { Text(title).font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary).padding(.horizontal, 24); content.padding(.horizontal, 24) } } }
struct StitchReportRow: View { let isTicker: Bool; var iconText: String = ""; var iconName: String = ""; var iconColor: Color = .blue; let title: String; let subtitle: String; let amount: Double; var body: some View { HStack(spacing: 16) { ZStack { Circle().fill(isTicker ? Color(hex: "F4F6F9") : iconColor.opacity(0.1)).frame(width: 44, height: 44); if isTicker { Text(iconText).font(.system(size: 12, weight: .bold)).foregroundColor(.primary) } else { Image(systemName: iconName).font(.system(size: 18, weight: .semibold)).foregroundColor(iconColor) } }; VStack(alignment: .leading, spacing: 4) { Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(.primary); Text(subtitle).font(.system(size: 13)).foregroundColor(.secondary) }; Spacer(); Text(formatAmount(amount)).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(amount >= 0 ? .green : .red) }.padding(.horizontal, 16).padding(.vertical, 14).background(Color.white) }; private func formatAmount(_ val: Double) -> String { let f = NumberFormatter(); f.numberStyle = .decimal; f.maximumFractionDigits = 2; f.minimumFractionDigits = 2; let s = f.string(from: NSNumber(value: abs(val))) ?? "0,00"; return val > 0 ? "+\(s) ₺" : (val < 0 ? "-\(s) ₺" : "\(s) ₺") } }
struct EmptyReportRow: View { let message: String; var body: some View { HStack { Spacer(); Text(message).font(.system(size: 14)).foregroundColor(.secondary.opacity(0.8)).padding(.vertical, 16); Spacer() }.background(Color.white).clipShape(RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.1), lineWidth: 1)) } }
