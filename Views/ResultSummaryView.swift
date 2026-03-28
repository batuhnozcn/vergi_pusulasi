import SwiftUI
import SwiftData
import FirebaseAuth

struct ResultSummaryView: View {
    @Environment(\.dismiss) var dismiss
    @Query(sort: \TradeTransaction.date, order: .reverse) private var transactions: [TradeTransaction]
    
    @EnvironmentObject var storeManager: StoreManager
    @AppStorage("selectedTaxYear") private var selectedYear = "2026"
    @AppStorage("userName") private var userName = "Batuhan"
    
    @State private var showShareSheet = false
    @State private var pdfURL: URL? = nil
    
    var userTransactions: [TradeTransaction] {
        let currentUserId = Auth.auth().currentUser?.uid ?? ""
        return transactions.filter { $0.userId == currentUserId }
    }
    
    var filteredTransactions: [TradeTransaction] {
        if selectedYear == "Tümü" { return userTransactions }
        return userTransactions.filter { String(Calendar.current.component(.year, from: $0.date)) == selectedYear }
    }
    
    var numericYear: Int { Int(selectedYear) ?? Calendar.current.component(.year, from: Date()) }
    
    var body: some View {
        let gains = PortfolioCalculationService.shared.calculateGains(from: userTransactions)
        let summary = TaxComputationService.shared.calculateSummary(
            transactions: userTransactions,
            gains: gains,
            year: numericYear,
            isPremium: storeManager.isPremium
        )
        
        ZStack {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    
                    VStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Color(hex: "1F5EFF").opacity(0.1)).frame(width: 80, height: 80)
                            Image(systemName: "doc.text.viewfinder")
                                .font(.system(size: 32, weight: .light))
                                .foregroundColor(Color(hex: "1F5EFF"))
                        }
                        
                        Text("\(selectedYear) Vergi Raporu")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text("Mükellef: \(userName)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 24)
                    
                    VStack(spacing: 0) {
                        SummaryRow(title: "Değer Artış Kazancı (Hisse)", value: formatTL(summary.netProfit))
                        Divider().padding(.vertical, 4)
                        
                        SummaryRow(title: "Temettü Gelirleri", value: formatTL(summary.dividendTotal))
                        Divider().padding(.vertical, 4)
                        
                        if summary.otherIncome > 0 {
                            SummaryRow(title: "Diğer Gelirler", value: formatTL(summary.otherIncome))
                            Divider().padding(.vertical, 4)
                        }
                        
                        let exemption = 0.0
                        SummaryRow(title: "Vergi İstisnası / İndirim", value: "-\(formatTL(exemption))", color: .green)
                        Divider().padding(.vertical, 4)
                        
                        SummaryRow(title: "Toplam Beyan Matrahı", value: formatTL(summary.taxBase), isBold: true)
                        
                        if summary.foreignTaxCredit > 0 {
                            Divider().padding(.vertical, 4)
                            SummaryRow(title: "Yurtdışı Vergi Mahsubu", value: "-\(formatTL(summary.foreignTaxCredit))", color: .green)
                        }
                    }
                    .padding(16)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.02), radius: 5, y: 2)
                    .padding(.horizontal, 24)
                    
                    VStack(spacing: 8) {
                        Text("Tahmini Ödenecek Vergi")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(formatTL(summary.totalTax))
                            .font(.system(size: 36, weight: .heavy, design: .rounded))
                            .foregroundColor(Color(hex: "1F5EFF"))
                    }
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.02), radius: 5, y: 2)
                    .padding(.horizontal, 24)
                    
                    Spacer(minLength: 20)
                    
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        
                        let filteredGains = gains.filter { Calendar.current.component(.year, from: $0.sellDate) == numericYear }
                        
                        // 🚀 DÜZELTME: PDF Motoruna artık doğrudan zeki 'summary' objesini gönderiyoruz!
                        pdfURL = PDFManager.render(
                            year: selectedYear,
                            userName: userName,
                            transactions: filteredTransactions,
                            gains: filteredGains,
                            summary: summary,
                            advisorFirmName: nil
                        )
                        if pdfURL != nil { showShareSheet = true }
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up.fill")
                            Text("Raporu Dışarı Aktar (PDF)")
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(hex: "1F5EFF"))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color(hex: "1F5EFF").opacity(0.3), radius: 10, y: 5)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationTitle("Vergi Raporu")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShareSheet) {
            if let url = pdfURL { ShareSheet(items: [url]) }
        }
    }
    
    private func formatTL(_ val: Double) -> String {
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencySymbol = "₺"; f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: val)) ?? "₺0"
    }
}

struct SummaryRow: View {
    var title: String
    var value: String
    var isBold: Bool = false
    var color: Color = .primary
    
    var body: some View {
        HStack {
            Text(title).font(.system(size: 14, weight: isBold ? .bold : .medium)).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.system(size: 15, weight: isBold ? .heavy : .bold, design: .rounded)).foregroundColor(color)
        }
    }
}
