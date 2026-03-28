import SwiftUI
import SwiftData
import FirebaseAuth

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
        @Query private var userTransactions: [TradeTransaction] // 🚀 YENİ
        
        @EnvironmentObject var storeManager: StoreManager
        
        @AppStorage("userName") private var userName = ""
        @AppStorage("isBalanceHidden") private var isBalanceHidden = false
        @AppStorage("selectedTaxYear") private var selectedYear = "2026"
        @State private var liveUSDRate: Double? = nil
        
        @State private var transactionToDelete: TradeTransaction? = nil
        @State private var showDeleteAlert = false
        @State private var showingCloudError = false
        @State private var cloudErrorMessage = ""
        
        init() {
            let currentUserId = Auth.auth().currentUser?.uid ?? ""
            let predicate = #Predicate<TradeTransaction> { $0.userId == currentUserId }
            _userTransactions = Query(filter: predicate, sort: \.date, order: .reverse)
        }
    
    var filteredTransactions: [TradeTransaction] {
        let base = selectedYear == "Tümü" ? userTransactions : userTransactions.filter { String(Calendar.current.component(.year, from: $0.date)) == selectedYear }
        return base.sorted { $0.date > $1.date }
    }
    
    var numericYear: Int { Int(selectedYear) ?? Calendar.current.component(.year, from: Date()) }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            Color.clear.frame(height: 0).id("top")
                            
                            HStack {
                                NavigationLink(destination: ProfileEditView()) {
                                    HStack(spacing: 12) {
                                        ZStack(alignment: .bottomTrailing) { Circle().fill(Color(hex: "FFE4C4")).frame(width: 44, height: 44).overlay(Image(systemName: "person.fill").foregroundColor(Color.orange.opacity(0.5))); Circle().fill(Color.green).frame(width: 12, height: 12).overlay(Circle().stroke(Color(UIColor.systemGroupedBackground), lineWidth: 2)) }
                                        VStack(alignment: .leading, spacing: 2) { Text("Hoş geldin,").font(.system(size: 13, weight: .medium)).foregroundColor(.secondary); Text(userName.split(separator: " ").first.map(String.init) ?? userName).font(.system(size: 16, weight: .bold)).foregroundColor(.primary) }
                                    }
                                }
                                Spacer()
                                Menu { Button("2026") { selectedYear = "2026" }; Button("2025") { selectedYear = "2025" }; Button("2024") { selectedYear = "2024" }; Button("2023") { selectedYear = "2023" } } label: { HStack(spacing: 6) { Text(selectedYear == "Tümü" ? "2026" : selectedYear).font(.system(size: 14, weight: .bold)); Image(systemName: "chevron.down").font(.system(size: 12, weight: .bold)) }.foregroundColor(Color(hex: "1F5EFF")).padding(.horizontal, 14).padding(.vertical, 8).background(Color(hex: "1F5EFF").opacity(0.1)).clipShape(Capsule()) }
                                Button(action: { UIImpactFeedbackGenerator(style: .light).impactOccurred(); withAnimation(.easeInOut) { isBalanceHidden.toggle() } }) { Circle().fill(Color(UIColor.secondarySystemGroupedBackground)).frame(width: 40, height: 40).overlay(Image(systemName: isBalanceHidden ? "eye.slash.fill" : "eye.fill").foregroundColor(.primary)).shadow(color: .black.opacity(0.03), radius: 5, y: 2) }
                            }.padding(.horizontal, 24).padding(.top, 10)
                            
                            HStack {
                                HStack(spacing: 6) { Image(systemName: "chart.line.uptrend.xyaxis").foregroundColor(.green); Text(liveUSDRate != nil ? "USD/TRY: \(String(format: "%.2f", liveUSDRate!).replacingOccurrences(of: ".", with: ","))" : "USD/TRY: Yükleniyor...").font(.system(size: 13, weight: .bold)).foregroundColor(.primary) }.padding(.horizontal, 16).padding(.vertical, 10).background(Color(UIColor.secondarySystemGroupedBackground)).clipShape(Capsule()).shadow(color: .black.opacity(0.02), radius: 4, y: 2)
                                Spacer(); Text("SON GÜNCEL: \(Date().formatted(.dateTime.hour().minute()))").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
                            }.padding(.horizontal, 24)
                            
                            let allGains = PortfolioCalculationService.shared.calculateGains(from: userTransactions)
                            let summary = TaxComputationService.shared.calculateSummary(
                                transactions: userTransactions,
                                gains: allGains,
                                year: numericYear,
                                isPremium: storeManager.isPremium
                            )
                            
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Text("\(selectedYear) Tahmini Vergi").font(.system(size: 15, weight: .medium)).foregroundColor(.white.opacity(0.8)); Spacer()
                                    Text(verbatim: "\(numericYear + 1) Mart Beyanı").font(.system(size: 11, weight: .bold)).foregroundColor(Color(hex: "0D1425")).padding(.horizontal, 8).padding(.vertical, 4).background(Color.yellow).clipShape(Capsule())
                                }
                                Group { if isBalanceHidden { Text("₺***,**").font(.system(size: 42, weight: .bold, design: .rounded)) } else { let formattedTax = formatCurrencySplit(summary.grossTax); HStack(alignment: .firstTextBaseline, spacing: 2) { Text("₺").font(.system(size: 32, weight: .semibold, design: .rounded)); Text(formattedTax.integer).font(.system(size: 44, weight: .bold, design: .rounded)); Text(",\(formattedTax.fraction)").font(.system(size: 24, weight: .semibold, design: .rounded)).foregroundColor(.white.opacity(0.6)) } } }.foregroundColor(.white)
                                VStack(spacing: 8) { HStack { Spacer(); Text("%\(summary.bracketInfo.rate) Oran").font(.system(size: 13, weight: .medium)).foregroundColor(.white) }; GeometryReader { geometry in ZStack(alignment: .leading) { Capsule().frame(width: geometry.size.width, height: 6).foregroundColor(.white.opacity(0.15)); Capsule().frame(width: max(0, geometry.size.width * summary.bracketInfo.progress), height: 6).foregroundColor(Color(hex: "3B7CFF")) } }.frame(height: 6) }.padding(.top, 4)
                            }.padding(24).background(Color(hex: "0D1425")).clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous)).shadow(color: Color(hex: "0D1425").opacity(0.15), radius: 15, y: 8).padding(.horizontal, 24)
                            
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                                MiniStatCard(icon: "chart.line.uptrend.xyaxis", iconColor: .green, title: "TOPLAM GELİR", amount: summary.grossTotalIncome, isHidden: isBalanceHidden)
                                MiniStatCard(icon: "wallet.pass.fill", iconColor: .blue, title: "MATRAH", amount: summary.taxBase, isHidden: isBalanceHidden)
                                MiniStatCard(icon: "banknote.fill", iconColor: .purple, title: "TEMETTÜ", amount: summary.dividendTotal, isHidden: isBalanceHidden)
                                TaxBracketCard(bracketInfo: summary.bracketInfo, isHidden: isBalanceHidden)
                            }.padding(.horizontal, 24)
                            
                            VStack(spacing: 16) {
                                HStack { Text("Son İşlemler").font(.system(size: 18, weight: .bold)).foregroundColor(.primary); Spacer(); NavigationLink(destination: HistoryView()) { Text("Tümünü Gör").font(.system(size: 14, weight: .semibold)).foregroundColor(Color(hex: "1F5EFF")) } }.padding(.horizontal, 24)
                                
                                if filteredTransactions.isEmpty {
                                    HStack { Spacer(); Text("\(selectedYear) yılında gelir işlemi bulunamadı.").font(.system(size: 14)).foregroundColor(.secondary).padding(.vertical, 20); Spacer() }.background(Color(UIColor.secondarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 16)).padding(.horizontal, 24)
                                } else {
                                    VStack(spacing: 12) {
                                        ForEach(filteredTransactions.prefix(3)) { transaction in
                                            StitchTransactionRow(transaction: transaction, isHidden: isBalanceHidden)
                                        }
                                    }.padding(.horizontal, 24)
                                }
                            }
                            Spacer(minLength: 24)
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ScrollToTop"))) { notif in if let tab = notif.object as? Int, tab == 0 { withAnimation { proxy.scrollTo("top", anchor: .top) } } }
                }
            }
        }
        .onAppear { Task { if let rate = await TCMBService.shared.fetchRate(for: Date()) { await MainActor.run { self.liveUSDRate = rate } } } }
        .alert("İşlemi Sil", isPresented: $showDeleteAlert) { Button("İptal", role: .cancel) { transactionToDelete = nil }; Button("Sil", role: .destructive) { if let tx = transactionToDelete { deleteTransaction(tx) } } } message: { Text("Bu işlemi silmek istediğinize emin misiniz? Bu işlem cihazınızdan ve buluttan kalıcı olarak silinecektir.") }
        .alert("Senkronizasyon Hatası", isPresented: $showingCloudError) { Button("Tamam", role: .cancel) { } } message: { Text(cloudErrorMessage) }
    }
    
    private func deleteTransaction(_ transaction: TradeTransaction) { UIImpactFeedbackGenerator(style: .medium).impactOccurred(); let id = transaction.id; withAnimation { modelContext.delete(transaction) }; transactionToDelete = nil; Task { do { try await FirebaseManager.shared.markAsDeleted(id: id) } catch { await MainActor.run { cloudErrorMessage = "Bulut senkronizasyon hatası."; showingCloudError = true } } } }
    private func formatCurrencySplit(_ value: Double) -> (integer: String, fraction: String) { let f = NumberFormatter(); f.numberStyle = .decimal; f.maximumFractionDigits = 2; f.minimumFractionDigits = 2; let str = f.string(from: NSNumber(value: value)) ?? "0,00"; let parts = str.split(separator: ","); if parts.count == 2 { return (String(parts[0]), String(parts[1])) }; return (str, "00") }
}

struct MiniStatCard: View { let icon: String; let iconColor: Color; let title: String; let amount: Double; let isHidden: Bool; var body: some View { VStack(alignment: .leading, spacing: 0) { Circle().fill(iconColor.opacity(0.1)).frame(width: 32, height: 32).overlay(Image(systemName: icon).font(.system(size: 14, weight: .bold)).foregroundColor(iconColor)); Spacer(); VStack(alignment: .leading, spacing: 2) { Text(title).font(.system(size: 10, weight: .bold)).foregroundColor(.secondary.opacity(0.8)); if isHidden { Text("₺***").font(.system(size: 17, weight: .bold, design: .rounded)).foregroundColor(.primary) } else { Text(formatCurrency(amount)).font(.system(size: 17, weight: .bold, design: .rounded)).foregroundColor(.primary).minimumScaleFactor(0.6).lineLimit(1) } } }.frame(maxWidth: .infinity, alignment: .leading).padding(12).frame(height: 96).background(Color(UIColor.secondarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 16)).shadow(color: .black.opacity(0.02), radius: 5, y: 2) }; private func formatCurrency(_ value: Double) -> String { let f = NumberFormatter(); f.numberStyle = .currency; f.currencySymbol = "₺"; f.maximumFractionDigits = 0; return f.string(from: NSNumber(value: value)) ?? "₺0" } }
struct TaxBracketCard: View { let bracketInfo: BracketInfo; let isHidden: Bool; var body: some View { VStack(alignment: .leading, spacing: 0) { HStack(alignment: .top) { Circle().fill(Color.orange.opacity(0.1)).frame(width: 32, height: 32).overlay(Text("%").font(.system(size: 16, weight: .bold)).foregroundColor(.orange)); Spacer(); Text("\(bracketInfo.bracketIndex). Dilim").font(.system(size: 9, weight: .semibold)).foregroundColor(.secondary).padding(.horizontal, 8).padding(.vertical, 4).background(Color.gray.opacity(0.1)).clipShape(Capsule()) }; Spacer(); VStack(alignment: .leading, spacing: 4) { Text("VERGİ DİLİMİ").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary.opacity(0.8)); HStack(alignment: .lastTextBaseline, spacing: 2) { Text("%\(bracketInfo.rate)").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.primary); Spacer(); Text(isHidden ? "Sonraki: ***" : "Kalan: \(formatCompact(bracketInfo.remaining))₺").font(.system(size: 9)).foregroundColor(.secondary).lineLimit(1).minimumScaleFactor(0.8) }; GeometryReader { geometry in ZStack(alignment: .leading) { Capsule().frame(width: geometry.size.width, height: 4).foregroundColor(.gray.opacity(0.15)); Capsule().frame(width: max(0, geometry.size.width * bracketInfo.progress), height: 4).foregroundColor(.orange) } }.frame(height: 4) } }.frame(maxWidth: .infinity, alignment: .leading).padding(12).frame(height: 96).background(Color(UIColor.secondarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 16)).shadow(color: .black.opacity(0.02), radius: 5, y: 2) }; private func formatCompact(_ value: Double) -> String { value >= 1000 ? "\(Int(value / 1000))K" : "\(Int(value))" } }
struct StitchTransactionRow: View { let transaction: TradeTransaction; let isHidden: Bool; var body: some View { HStack(spacing: 16) { ZStack { Circle().fill(iconBgColor).frame(width: 44, height: 44); Image(systemName: iconName).font(.system(size: 16, weight: .semibold)).foregroundColor(iconColor) }; VStack(alignment: .leading, spacing: 4) { Text("\(transaction.ticker) \(typeText)").font(.system(size: 15, weight: .bold)).foregroundColor(.primary); Text(dateString).font(.system(size: 12)).foregroundColor(.secondary) }; Spacer(); VStack(alignment: .trailing, spacing: 4) { Text(isHidden ? "₺***" : amountString).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(amountColor); Text(String(format: "%.2f Adet", transaction.quantity)).font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary) } }.padding(16).background(Color(UIColor.secondarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 16)).shadow(color: .black.opacity(0.02), radius: 5, y: 2) }; var typeText: String { switch transaction.type { case .buy: return "Alış"; case .sell: return "Satış"; case .dividend: return "Temettü"; case .other: return "Diğer" } }; var iconName: String { switch transaction.type { case .buy: return "arrow.down.left"; case .sell: return "arrow.up.right"; case .dividend: return "dollarsign.circle.fill"; case .other: return "bag.fill" } }; var iconColor: Color { switch transaction.type { case .buy: return .gray; case .sell: return .blue; case .dividend: return .green; case .other: return .purple } }; var iconBgColor: Color { iconColor.opacity(0.1) }; var amountColor: Color { switch transaction.type { case .buy: return .primary; case .sell: return .blue; case .dividend: return .green; case .other: return .purple } }; var dateString: String { let f = DateFormatter(); f.dateFormat = "dd MMM yyyy"; f.locale = Locale(identifier: "tr_TR"); return f.string(from: transaction.date) }; var amountString: String { let val = transaction.priceUSD * transaction.quantity * transaction.fxRate; let f = NumberFormatter(); f.numberStyle = .currency; f.currencySymbol = "₺"; f.maximumFractionDigits = 0; return f.string(from: NSNumber(value: val)) ?? "₺0" } }
struct SwipeableRow<Content: View>: View { let onEdit: () -> Void; let onDelete: () -> Void; let content: Content; @State private var offset: CGFloat = 0; init(onEdit: @escaping () -> Void, onDelete: @escaping () -> Void, @ViewBuilder content: () -> Content) { self.onEdit = onEdit; self.onDelete = onDelete; self.content = content() }; var body: some View { ZStack(alignment: .trailing) { HStack(spacing: 0) { Spacer(); Button(action: { withAnimation(.spring()) { offset = 0 }; onEdit() }) { VStack(spacing: 4) { Image(systemName: "pencil").font(.system(size: 16)); Text("Düzenle").font(.system(size: 10, weight: .bold)) }.foregroundColor(.white).frame(width: 75).frame(maxHeight: .infinity).background(Color.blue) }; Button(action: { withAnimation(.spring()) { offset = 0 }; onDelete() }) { VStack(spacing: 4) { Image(systemName: "trash.fill").font(.system(size: 16)); Text("Sil").font(.system(size: 10, weight: .bold)) }.foregroundColor(.white).frame(width: 75 + (offset < -150 ? abs(offset) - 150 : 0)).frame(maxHeight: .infinity).background(Color.red) } }.clipShape(RoundedRectangle(cornerRadius: 16)); content.background(Color(UIColor.systemGroupedBackground)).offset(x: offset).gesture(DragGesture().onChanged { value in if value.translation.width < 0 { offset = value.translation.width } }.onEnded { value in withAnimation(.spring()) { if value.translation.width < -200 { offset = 0; onDelete() } else if value.translation.width < -80 { offset = -150 } else { offset = 0 } } }) } }
}
