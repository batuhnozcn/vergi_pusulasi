import SwiftUI
import SwiftData

struct EditTransactionView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var transaction: TradeTransaction
    
    @State private var ticker: String
    @State private var quantity: String
    @State private var priceUSD: String
    @State private var commissionUSD: String
    @State private var date: Date
    @State private var fxRate: String
    @State private var otherType: String
    
    @State private var isFetchingRate = false
    @State private var showingCloudError = false
    @State private var cloudErrorMessage = ""
    
    init(transaction: TradeTransaction) {
        self.transaction = transaction
        _ticker = State(initialValue: transaction.type == .other ? "" : transaction.ticker)
        _otherType = State(initialValue: transaction.type == .other ? transaction.ticker : "")
        _date = State(initialValue: transaction.date)
        _quantity = State(initialValue: String(format: "%g", transaction.quantity).replacingOccurrences(of: ".", with: ","))
        _priceUSD = State(initialValue: String(format: "%g", transaction.priceUSD).replacingOccurrences(of: ".", with: ","))
        _commissionUSD = State(initialValue: String(format: "%g", transaction.commissionUSD).replacingOccurrences(of: ".", with: ","))
        _fxRate = State(initialValue: String(format: "%.4f", transaction.fxRate).replacingOccurrences(of: ".", with: ","))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        transactionTypeBadge
                        formFields.padding(.top, 4)
                        
                        Button(action: saveChanges) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill").font(.system(size: 16))
                                Text("Değişiklikleri Kaydet").font(.system(size: 14, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.green)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .padding(.top, 8)
                        
                        Spacer(minLength: 40)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("İşlemi Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Bitti") { hideKeyboard() }.font(.system(size: 16, weight: .bold)).foregroundColor(Color(hex: "1F5EFF"))
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Vazgeç") { dismiss() }.foregroundColor(Color(hex: "1F5EFF")).font(.system(size: 15))
                }
            }
            .onChange(of: date) { _, _ in fetchRate() }
            .onChange(of: ticker) { _, _ in if transaction.type != .other && ticker != ticker.uppercased() { ticker = ticker.uppercased() } }
        }
    }
    
    private var transactionTypeBadge: some View { HStack { let typeName = transaction.type == .buy ? "Hisse Alışı" : transaction.type == .sell ? "Hisse Satışı" : transaction.type == .dividend ? "Temettü Geliri" : "Diğer Gelir"; Text(typeName).font(.system(size: 13, weight: .bold)).foregroundColor(.secondary); Spacer() }.padding(.horizontal, 4) }
    
    @ViewBuilder
    private var formFields: some View {
        VStack(spacing: 12) {
            if transaction.type == .other {
                InputGroup(label: "Gelir Türü") { CustomField(placeholder: "Örn: Faiz Geliri", text: $otherType, icon: "bag") }
                InputGroup(label: "Tutar (USD)") { CustomField(placeholder: "0.00", text: $priceUSD, icon: "dollarsign", keyboardType: .decimalPad) }
                HStack(spacing: 12) { InputGroup(label: "İşlem Tarihi") { CustomDatePicker(selection: $date) }; FXInputGroup(label: "Döviz Kuru (₺)", isLoading: isFetchingRate) { CustomField(placeholder: "Otomatik", text: $fxRate, icon: "turkishlirasign", keyboardType: .decimalPad) } }
            } else if transaction.type == .dividend {
                InputGroup(label: "Hisse Senedi / Sembol") { CustomField(placeholder: "ÖRN: AAPL", text: $ticker, icon: "magnifyingglass") }
                InputGroup(label: "Brüt Temettü (USD)") { CustomField(placeholder: "0.00", text: $priceUSD, icon: "dollarsign", keyboardType: .decimalPad) }
                HStack(spacing: 12) { InputGroup(label: "Ödeme Tarihi") { CustomDatePicker(selection: $date) }; FXInputGroup(label: "Döviz Kuru (₺)", isLoading: isFetchingRate) { CustomField(placeholder: "Otomatik", text: $fxRate, icon: "turkishlirasign", keyboardType: .decimalPad) } }
                InputGroup(label: "Kesilen Stopaj (USD)") { CustomField(placeholder: "0.00", text: $commissionUSD, icon: "minus.circle", keyboardType: .decimalPad) }
            } else {
                InputGroup(label: "Hisse Senedi / Sembol") { CustomField(placeholder: "Örn: AAPL", text: $ticker, icon: "magnifyingglass") }
                HStack(spacing: 12) { InputGroup(label: "Adet") { CustomField(placeholder: "0", text: $quantity, icon: "number", keyboardType: .decimalPad) }; InputGroup(label: "Fiyat ($)") { CustomField(placeholder: "0.00", text: $priceUSD, icon: "dollarsign", keyboardType: .decimalPad) }; InputGroup(label: "Koms. ($)") { CustomField(placeholder: "0.00", text: $commissionUSD, icon: "minus.circle", keyboardType: .decimalPad) } }
                HStack(spacing: 12) { InputGroup(label: transaction.type == .buy ? "Alış Tarihi" : "Satış Tarihi") { CustomDatePicker(selection: $date) }; FXInputGroup(label: transaction.type == .buy ? "Alış Kuru (₺)" : "Satış Kuru (₺)", isLoading: isFetchingRate) { CustomField(placeholder: "Otomatik", text: $fxRate, icon: "turkishlirasign", keyboardType: .decimalPad) } }
            }
        }
    }
    
    // 🚀 KRİTİK DÜZELTME: T-1 Kuralı gereği fetchTransactionRate kullanıldı.
    private func fetchRate() {
        isFetchingRate = true
        Task {
            if let rate = await TCMBService.shared.fetchTransactionRate(for: date) {
                await MainActor.run {
                    self.fxRate = String(format: "%.4f", rate).replacingOccurrences(of: ".", with: ",")
                    self.isFetchingRate = false
                }
            } else {
                await MainActor.run {
                    self.isFetchingRate = false
                }
            }
        }
    }
    
    private func parseDouble(_ text: String) -> Double { Double(text.replacingOccurrences(of: ",", with: ".")) ?? 0.0 }
    
    private func saveChanges() {
        hideKeyboard()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        transaction.ticker = transaction.type == .other ? otherType : ticker.uppercased()
        transaction.date = date
        transaction.quantity = parseDouble(quantity)
        transaction.priceUSD = parseDouble(priceUSD)
        transaction.commissionUSD = parseDouble(commissionUSD)
        transaction.fxRate = parseDouble(fxRate)
        // 🚀 YENİ (GPT P0 Uyarısı): Bulutun değişikliği fark etmesi için güncelleme saatini mühürlüyoruz
        transaction.updatedAt = Date()
        
        try? modelContext.save()
        
        let safeCloudClone = TradeTransaction(
            ticker: transaction.ticker, type: transaction.type, quantity: transaction.quantity,
            priceUSD: transaction.priceUSD, commissionUSD: transaction.commissionUSD,
            date: transaction.date, fxRate: transaction.fxRate
        )
        safeCloudClone.id = transaction.id
        safeCloudClone.userId = transaction.userId
        safeCloudClone.updatedAt = transaction.updatedAt // Buluta güncel saati yolluyoruz
        
        dismiss()
        
        Task.detached { do { try await FirebaseManager.shared.saveTransaction(safeCloudClone) } catch { print("Bulut Hatası") } }
    }
}
