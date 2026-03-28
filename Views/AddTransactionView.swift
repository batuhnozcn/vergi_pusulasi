import SwiftUI
import SwiftData
import FirebaseAuth

#if canImport(UIKit)
extension View { func hideKeyboard() { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) } }
#endif

struct PendingEntry: Identifiable { let id = UUID(); let displayType: Int; let ticker: String; let date: Date; let fxRate: Double; let netAmountUSD: Double; let otherCategory: String; let transactions: [TradeTransaction] }

struct AddTransactionView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var storeManager: StoreManager
    @Query private var existingTransactions: [TradeTransaction]
    @State private var showPaywall = false
    
    @State private var selectedTab = 0
    @State private var transactionDate = Date(); @State private var fxRate: String = ""; @State private var isFetchingSellRate = false
    @State private var buyQuantity: String = ""; @State private var buyUnitPrice: String = ""; @State private var buyFxRate: String = ""; @State private var buyDate = Date(); @State private var isFetchingBuyRate = false
    @State private var ticker: String = ""; @State private var sellQuantity: String = ""; @State private var sellUnitPrice: String = ""
    @State private var grossDividend: String = ""; @State private var withholdingTax: String = ""
    @State private var otherType: String = "Faiz Geliri"; @State private var otherAmount: String = ""; @State private var otherDescription: String = ""
    @State private var buyCommission: String = ""; @State private var sellCommission: String = ""
    @State private var pendingItems: [PendingEntry] = []
    @State private var showingCloudError = false; @State private var cloudErrorMessage = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        NavigationLink(destination: ImportView()) { HStack { Image(systemName: "arrow.down.doc.fill"); Text("Ekstreden İçe Aktar") }.font(.system(size: 13, weight: .bold)).foregroundColor(Color(hex: "1F5EFF")).frame(maxWidth: .infinity).padding(.vertical, 12).background(Color(hex: "1F5EFF").opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 10)) }
                        HStack(spacing: 0) { SegmentButton(title: "Alış", isSelected: selectedTab == 0) { selectedTab = 0 }; SegmentButton(title: "Satış", isSelected: selectedTab == 1) { selectedTab = 1 }; SegmentButton(title: "Temettü", isSelected: selectedTab == 2) { selectedTab = 2 }; SegmentButton(title: "Diğer", isSelected: selectedTab == 3) { selectedTab = 3 } }.padding(4).background(Color.primary.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 10))
                        VStack(spacing: 12) { if selectedTab == 0 { hisseAlisFields } else if selectedTab == 1 { hisseSatisFields } else if selectedTab == 2 { temettuFields } else { digerFields } }.padding(.top, 4)
                        
                        VStack(spacing: 6) {
                            Button(action: addToList) { HStack { Image(systemName: "plus.circle.fill").font(.system(size: 16)); Text("Listeye Ekle").font(.system(size: 14, weight: .bold)) }.foregroundColor(Color(hex: "1F5EFF")).frame(maxWidth: .infinity).padding(.vertical, 12).background(Color(UIColor.secondarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color(hex: "1F5EFF"), style: StrokeStyle(lineWidth: 1.5, dash: [6]))) }
                            if !storeManager.isPremium {
                                // 🚀 YENİ: Sadece bu kullanıcının limitini hesapla
                                let currentUserId = Auth.auth().currentUser?.uid ?? ""
                                let userTransactionsCount = existingTransactions.filter { $0.userId == currentUserId }.count
                                let currentTotal = userTransactionsCount + pendingItems.reduce(0) { $0 + $1.transactions.count }
                                Text("Ücretsiz İşlem Limiti: \(currentTotal)/15").font(.system(size: 11, weight: .medium)).foregroundColor(currentTotal >= 15 ? .red : .secondary)
                            }
                        }.padding(.top, 8)
                        
                        if !pendingItems.isEmpty { VStack(alignment: .leading, spacing: 12) { HStack { Text("Eklenen İşlemler").font(.system(size: 15, weight: .bold)).foregroundColor(.primary); Spacer(); Text("\(pendingItems.count) Adet").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary) }; VStack(spacing: 8) { ForEach(pendingItems) { item in PendingItemCard(item: item) { if let index = pendingItems.firstIndex(where: { $0.id == item.id }) { pendingItems.remove(at: index) } } } } }.padding(.top, 8) }
                        Spacer(minLength: 40)
                    }.padding(16)
                }
            }
            .navigationTitle(navTitle).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Bitti") { hideKeyboard() }.font(.system(size: 16, weight: .bold)).foregroundColor(Color(hex: "1F5EFF")) }
                ToolbarItem(placement: .navigationBarLeading) { Button("Vazgeç") { dismiss() }.foregroundColor(Color(hex: "1F5EFF")).font(.system(size: 15)) }
                ToolbarItem(placement: .navigationBarTrailing) { Button("Kaydet") { saveToDatabase() }.font(.system(size: 15, weight: .bold)).foregroundColor(pendingItems.isEmpty ? .gray : Color(hex: "1F5EFF")).disabled(pendingItems.isEmpty) }
            }
            .onAppear { fetchBuyRate(); fetchSellRate() }.onChange(of: buyDate) { _, _ in fetchBuyRate() }.onChange(of: transactionDate) { _, _ in fetchSellRate() }.onChange(of: ticker) { _, _ in if ticker != ticker.uppercased() { ticker = ticker.uppercased() } }
            .alert("Bulut Yedekleme Hatası", isPresented: $showingCloudError) { Button("Tamam", role: .cancel) { dismiss() } } message: { Text(cloudErrorMessage) }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }
    
    var navTitle: String { switch selectedTab { case 0: return "Hisse Alışı"; case 1: return "Hisse Satışı"; case 2: return "Temettü Geliri"; default: return "Diğer Gelir" } }
    
    private func fetchBuyRate() { isFetchingBuyRate = true; Task { if let rate = await TCMBService.shared.fetchTransactionRate(for: buyDate) { await MainActor.run { self.buyFxRate = String(format: "%.4f", rate).replacingOccurrences(of: ".", with: ","); self.isFetchingBuyRate = false } } else { await MainActor.run { self.isFetchingBuyRate = false } } } }
    private func fetchSellRate() { isFetchingSellRate = true; Task { if let rate = await TCMBService.shared.fetchTransactionRate(for: transactionDate) { await MainActor.run { self.fxRate = String(format: "%.4f", rate).replacingOccurrences(of: ".", with: ","); self.isFetchingSellRate = false } } else { await MainActor.run { self.isFetchingSellRate = false } } } }
    
    private func addToList() {
        hideKeyboard();
        
        let currentUserId = Auth.auth().currentUser?.uid ?? ""
        
        // 🚀 YENİ: Limiti aşma kontrolünü aktif kullanıcının işlemlerine göre yapıyoruz
        let userTransactionsCount = existingTransactions.filter { $0.userId == currentUserId }.count
        let currentTotal = userTransactionsCount + pendingItems.reduce(0) { $0 + $1.transactions.count }
        
        if !storeManager.isPremium && currentTotal >= 15 {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            showPaywall = true
            return
        }
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let rate = parseDouble(fxRate); var newItem: PendingEntry?
        
        if selectedTab == 0 {
            let bQty = parseDouble(buyQuantity); let bPrice = parseDouble(buyUnitPrice); let bComm = parseDouble(buyCommission); let bRate = parseDouble(buyFxRate)
            let calculatedBuyAmount = (bQty * bPrice) + bComm
            if calculatedBuyAmount > 0 && !ticker.isEmpty { let buyTx = TradeTransaction(ticker: ticker.uppercased(), type: .buy, quantity: bQty, priceUSD: bPrice, commissionUSD: bComm, date: buyDate, fxRate: bRate); buyTx.userId = currentUserId; newItem = PendingEntry(displayType: 0, ticker: ticker.uppercased(), date: buyDate, fxRate: bRate, netAmountUSD: -calculatedBuyAmount, otherCategory: "", transactions: [buyTx]) }
        } else if selectedTab == 1 {
            let sQty = parseDouble(sellQuantity); let sPrice = parseDouble(sellUnitPrice); let sComm = parseDouble(sellCommission)
            let calculatedSellAmount = (sQty * sPrice) - sComm
            if calculatedSellAmount > 0 && !ticker.isEmpty { let sellTx = TradeTransaction(ticker: ticker.uppercased(), type: .sell, quantity: sQty, priceUSD: sPrice, commissionUSD: sComm, date: transactionDate, fxRate: rate); sellTx.userId = currentUserId; newItem = PendingEntry(displayType: 1, ticker: ticker.uppercased(), date: transactionDate, fxRate: rate, netAmountUSD: calculatedSellAmount, otherCategory: "", transactions: [sellTx]) }
        } else if selectedTab == 2 {
            let amount = parseDouble(grossDividend); let tax = parseDouble(withholdingTax)
            if amount > 0 && !ticker.isEmpty { let divTx = TradeTransaction(ticker: ticker.uppercased(), type: .dividend, quantity: 1.0, priceUSD: amount, commissionUSD: tax, date: transactionDate, fxRate: rate); divTx.userId = currentUserId; newItem = PendingEntry(displayType: 2, ticker: ticker.uppercased(), date: transactionDate, fxRate: rate, netAmountUSD: amount - tax, otherCategory: "", transactions: [divTx]) }
        } else {
            let amount = parseDouble(otherAmount)
            if amount > 0 { let otherTx = TradeTransaction(ticker: otherType, type: .other, quantity: 1.0, priceUSD: amount, commissionUSD: 0, date: transactionDate, fxRate: rate); otherTx.userId = currentUserId; newItem = PendingEntry(displayType: 3, ticker: "", date: transactionDate, fxRate: rate, netAmountUSD: amount, otherCategory: otherType, transactions: [otherTx]) }
        }
        if let item = newItem { withAnimation { pendingItems.insert(item, at: 0) }; clearFields() }
    }
    
    private func saveToDatabase() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred(); let itemsToSave = pendingItems
        for entry in itemsToSave { for tx in entry.transactions { modelContext.insert(tx) } }
        Task {
            var hasCloudError = false
            for entry in itemsToSave { for tx in entry.transactions { do { try await FirebaseManager.shared.saveTransaction(tx) } catch { hasCloudError = true } } }
            await MainActor.run { if hasCloudError { cloudErrorMessage = "İşlemler cihazınıza kaydedildi ancak bağlantı sorunu nedeniyle buluta yedeklenemedi."; showingCloudError = true } else { dismiss() } }
        }
    }
    
    private func clearFields() { ticker = ""; grossDividend = ""; withholdingTax = ""; otherAmount = ""; otherDescription = ""; buyQuantity = ""; buyUnitPrice = ""; sellQuantity = ""; sellUnitPrice = ""; buyCommission = ""; sellCommission = ""; fetchBuyRate(); fetchSellRate() }
    private func parseDouble(_ text: String) -> Double { Double(text.replacingOccurrences(of: ",", with: ".")) ?? 0.0 }
    
    private var hisseAlisFields: some View { VStack(spacing: 12) { InputGroup(label: "Hisse Senedi / Sembol") { CustomField(placeholder: "Örn: AAPL", text: $ticker, icon: "magnifyingglass") }; HStack(spacing: 12) { InputGroup(label: "Adet") { CustomField(placeholder: "0", text: $buyQuantity, icon: "number", keyboardType: .decimalPad) }; InputGroup(label: "Fiyat ($)") { CustomField(placeholder: "0.00", text: $buyUnitPrice, icon: "dollarsign", keyboardType: .decimalPad) }; InputGroup(label: "Koms. ($)") { CustomField(placeholder: "0.00", text: $buyCommission, icon: "minus.circle", keyboardType: .decimalPad) } }; HStack(spacing: 12) { InputGroup(label: "Alış Tarihi") { CustomDatePicker(selection: $buyDate) }; FXInputGroup(label: "Alış Kuru (₺)", isLoading: isFetchingBuyRate) { CustomField(placeholder: "Otomatik", text: $buyFxRate, icon: "turkishlirasign", keyboardType: .decimalPad) } } } }
    private var hisseSatisFields: some View { VStack(spacing: 12) { InputGroup(label: "Hisse Senedi / Sembol") { CustomField(placeholder: "Örn: AAPL", text: $ticker, icon: "magnifyingglass") }; HStack(spacing: 12) { InputGroup(label: "Adet") { CustomField(placeholder: "0", text: $sellQuantity, icon: "number", keyboardType: .decimalPad) }; InputGroup(label: "Fiyat ($)") { CustomField(placeholder: "0.00", text: $sellUnitPrice, icon: "dollarsign", keyboardType: .decimalPad) }; InputGroup(label: "Koms. ($)") { CustomField(placeholder: "0.00", text: $sellCommission, icon: "minus.circle", keyboardType: .decimalPad) } }; HStack(spacing: 12) { InputGroup(label: "Satış Tarihi") { CustomDatePicker(selection: $transactionDate) }; FXInputGroup(label: "Satış Kuru (₺)", isLoading: isFetchingSellRate) { CustomField(placeholder: "Otomatik", text: $fxRate, icon: "turkishlirasign", keyboardType: .decimalPad) } } } }
    private var temettuFields: some View { VStack(spacing: 12) { InputGroup(label: "Hisse Senedi / Sembol") { CustomField(placeholder: "ÖRN: AAPL", text: $ticker, icon: "magnifyingglass") }; InputGroup(label: "Brüt Temettü (USD)") { CustomField(placeholder: "0.00", text: $grossDividend, icon: "dollarsign", keyboardType: .decimalPad) }; HStack(spacing: 12) { InputGroup(label: "Ödeme Tarihi") { CustomDatePicker(selection: $transactionDate) }; FXInputGroup(label: "Döviz Kuru (₺)", isLoading: isFetchingSellRate) { CustomField(placeholder: "Otomatik", text: $fxRate, icon: "turkishlirasign", keyboardType: .decimalPad) } }; InputGroup(label: "Kesilen Stopaj (USD)") { CustomField(placeholder: "0.00", text: $withholdingTax, icon: "minus.circle", keyboardType: .decimalPad) } } }
    private var digerFields: some View { VStack(spacing: 12) { InputGroup(label: "Gelir Türü") { HStack { Text(otherType).font(.system(size: 14)).foregroundColor(.primary); Spacer(); Image(systemName: "chevron.down").foregroundColor(.secondary).font(.system(size: 12)) }.padding(.horizontal, 12).frame(height: 44).background(Color(UIColor.secondarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.15), lineWidth: 1)) }; InputGroup(label: "Tutar (USD)") { CustomField(placeholder: "0.00", text: $otherAmount, icon: "dollarsign", keyboardType: .decimalPad) }; HStack(spacing: 12) { InputGroup(label: "İşlem Tarihi") { CustomDatePicker(selection: $transactionDate) }; FXInputGroup(label: "Döviz Kuru (₺)", isLoading: isFetchingSellRate) { CustomField(placeholder: "Otomatik", text: $fxRate, icon: "turkishlirasign", keyboardType: .decimalPad) } }; InputGroup(label: "Açıklama") { TextField("Not ekleyin...", text: $otherDescription).font(.system(size: 14)).padding(.horizontal, 12).frame(height: 44).background(Color(UIColor.secondarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.15), lineWidth: 1)) } } }
}

struct FXInputGroup<Content: View>: View { let label: String; let isLoading: Bool; let content: Content; init(label: String, isLoading: Bool, @ViewBuilder content: () -> Content) { self.label = label; self.isLoading = isLoading; self.content = content() }; var body: some View { VStack(alignment: .leading, spacing: 6) { HStack { Text(label).font(.system(size: 12, weight: .medium)).foregroundColor(.secondary); Spacer(); if isLoading { ProgressView().scaleEffect(0.6).frame(height: 14) } else { Text("TCMB").font(.system(size: 9, weight: .bold)).foregroundColor(.green).padding(.horizontal, 6).padding(.vertical, 3).background(Color.green.opacity(0.1)).clipShape(Capsule()) } }; content } } }
struct InputGroup<Content: View>: View { let label: String; let content: Content; init(label: String, @ViewBuilder content: () -> Content) { self.label = label; self.content = content() }; var body: some View { VStack(alignment: .leading, spacing: 6) { Text(label).font(.system(size: 12, weight: .medium)).foregroundColor(.secondary); content } } }
struct CustomField: View { let placeholder: String; @Binding var text: String; let icon: String; var keyboardType: UIKeyboardType = .default; var body: some View { HStack(spacing: 10) { Image(systemName: icon).foregroundColor(.secondary.opacity(0.5)).font(.system(size: 14)).frame(width: 16); TextField(placeholder, text: $text).keyboardType(keyboardType).font(.system(size: 14)) }.padding(.horizontal, 12).frame(height: 44).background(Color(UIColor.secondarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.15), lineWidth: 1)) } }
struct CustomDatePicker: View { @Binding var selection: Date; var body: some View { HStack { Image(systemName: "calendar").foregroundColor(.secondary.opacity(0.5)).font(.system(size: 14)); DatePicker("", selection: $selection, displayedComponents: .date).labelsHidden().environment(\.locale, Locale(identifier: "tr_TR")).scaleEffect(0.9); Spacer() }.padding(.horizontal, 12).frame(height: 44).background(Color(UIColor.secondarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.15), lineWidth: 1)) } }
struct SegmentButton: View { let title: String; let isSelected: Bool; let action: () -> Void; var body: some View { Button(action: { hideKeyboard(); action() }) { Text(title).font(.system(size: 13, weight: isSelected ? .bold : .medium)).foregroundColor(isSelected ? Color(hex: "1F5EFF") : .secondary).frame(maxWidth: .infinity).padding(.horizontal, 8).padding(.vertical, 8).background(isSelected ? Color(UIColor.secondarySystemGroupedBackground) : Color.clear).clipShape(RoundedRectangle(cornerRadius: 8)).shadow(color: isSelected ? .black.opacity(0.04) : .clear, radius: 4, y: 2) } } }

struct PendingItemCard: View { let item: PendingEntry; let onDelete: () -> Void; var body: some View { HStack(spacing: 12) { ZStack { Circle().fill(iconColor.opacity(0.1)).frame(width: 36, height: 36); if item.displayType == 0 || item.displayType == 1 { Text(item.ticker.isEmpty ? "St" : String(item.ticker.prefix(4))).font(.system(size: 10, weight: .bold)).foregroundColor(iconColor) } else { Image(systemName: iconName).font(.system(size: 14, weight: .bold)).foregroundColor(iconColor) } }; VStack(alignment: .leading, spacing: 2) { Text(titleText).font(.system(size: 14, weight: .bold)).foregroundColor(.primary); Text("Kur: \(String(format: "%.2f", item.fxRate))").font(.system(size: 11)).foregroundColor(.secondary) }; Spacer(); HStack(spacing: 8) { Text("$\(String(format: "%.2f", abs(item.netAmountUSD)))").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(item.displayType == 0 ? .primary : (item.netAmountUSD >= 0 ? .green : .red)); Button(action: onDelete) { Image(systemName: "trash.fill").font(.system(size: 14)).foregroundColor(.red.opacity(0.7)).padding(8) } } }.padding(12).background(Color(UIColor.secondarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 12)).shadow(color: .black.opacity(0.02), radius: 5, y: 2) }; var iconColor: Color { switch item.displayType { case 0: return .gray; case 1: return .blue; case 2: return .green; default: return .purple } }; var iconName: String { switch item.displayType { case 0: return "arrow.down.left"; case 1: return "arrow.up.right"; case 2: return "dollarsign.circle.fill"; default: return "bag.fill" } }; var titleText: String { switch item.displayType { case 0: return "\(item.ticker) Alış"; case 1: return "\(item.ticker) Satış"; case 2: return "\(item.ticker) Temettü"; default: return item.otherCategory.isEmpty ? "Diğer" : item.otherCategory } } }
