import SwiftUI
import SwiftData
import UIKit

// MARK: - DİZİ BÖLME YARDIMCISI
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

// MARK: - 1. PDF TASARIM BİLEŞENLERİ
struct PDFHeader: View {
    let year: String
    let userName: String
    var advisorFirmName: String? = nil
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("VERGİ PUSULASI").font(.system(size: 26, weight: .heavy, design: .rounded)).foregroundColor(Color(hex: "1F5EFF"))
                Text("\(year) Yılı Menkul Sermaye İradı Raporu").font(.system(size: 12, weight: .bold)).foregroundColor(.gray)
                
                if let firmName = advisorFirmName, !firmName.isEmpty {
                    Text("Hazırlayan: \(firmName)")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(Color(hex: "1F5EFF"))
                        .padding(.top, 4)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("MÜKELLEF").font(.system(size: 9, weight: .bold)).foregroundColor(.gray)
                Text(userName).font(.system(size: 14, weight: .bold))
                Text("Tarih: \(Date().formatted(.dateTime.day().month().year()))").font(.system(size: 9)).foregroundColor(.gray)
            }
        }
    }
}

struct PDFSummaryDashboard: View {
    let taxBase: Double
    let totalTax: Double
    let stockProfit: Double
    let dividend: Double
    let otherIncome: Double
    let foreignTax: Double
    let inflationAdvantage: Double
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                SummaryMiniCard(title: "BEYAN MATRAHI", amount: taxBase, bgColor: Color(hex: "0D1425"))
                SummaryMiniCard(title: "HESAPLANAN TAHMİNİ VERGİ", amount: totalTax, bgColor: Color(hex: "1F5EFF"))
            }
            
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("MATRAH KIRILIMI").font(.system(size: 10, weight: .bold)).foregroundColor(.gray)
                    VStack(spacing: 6) {
                        BreakdownRow(title: "Hisse Senedi Kârı", amount: stockProfit)
                        BreakdownRow(title: "Temettü Gelirleri", amount: dividend)
                        if otherIncome > 0 { BreakdownRow(title: "Diğer Gelirler", amount: otherIncome) }
                        if foreignTax > 0 { BreakdownRow(title: "Yurtdışı Vergi Mahsubu", amount: -foreignTax, color: .red) }
                    }
                }
                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(white: 0.96)).clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("UYGULANAN AVANTAJLAR").font(.system(size: 10, weight: .bold)).foregroundColor(.gray)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "shield.fill").foregroundColor(.green).font(.system(size: 12))
                            Text("Yİ-ÜFE Enflasyon Kalkanı").font(.system(size: 11, weight: .bold))
                        }
                        Text("Yasal enflasyon endekslemesi sayesinde aşağıdaki tutar kadar hayali kâr vergiden istisna edilmiştir.")
                            .font(.system(size: 9)).foregroundColor(.secondary).lineLimit(3)
                        Text(formatCurrency(inflationAdvantage)).font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundColor(.green).padding(.top, 2)
                    }
                    .padding(10).background(Color.green.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencySymbol = "₺"; f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "₺0"
    }
}

struct SummaryMiniCard: View {
    let title: String; let amount: Double; let bgColor: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 10, weight: .bold)).foregroundColor(.white.opacity(0.8))
            Text(formatCurrency(amount)).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundColor(.white)
        }
        .padding(.vertical, 12).padding(.horizontal, 16).frame(maxWidth: .infinity, alignment: .leading)
        .background(bgColor).clipShape(RoundedRectangle(cornerRadius: 8))
    }
    private func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencySymbol = "₺"; f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: value)) ?? "₺0"
    }
}

struct BreakdownRow: View {
    let title: String; let amount: Double; var color: Color = .primary
    var body: some View {
        HStack {
            Text(title).font(.system(size: 10, weight: .medium)).foregroundColor(.secondary)
            Spacer()
            Text(formatCurrency(amount)).font(.system(size: 10, weight: .bold, design: .rounded)).foregroundColor(color)
        }
    }
    private func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter(); f.numberStyle = .decimal; f.maximumFractionDigits = 2; f.minimumFractionDigits = 2
        let s = f.string(from: NSNumber(value: abs(value))) ?? "0,00"
        return value < 0 ? "-\(s) ₺" : "\(s) ₺"
    }
}

// MARK: - 2. ŞEFFAF TABLOLAR
struct PDFGainsTable: View {
    let gains: [RealizedGain]
    let showTitle: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showTitle { Text("A. DEĞER ARTIŞ KAZANÇLARI (HİSSE SATIŞLARI)").font(.system(size: 12, weight: .bold)).foregroundColor(Color(hex: "1F5EFF")).padding(.top, 10) }
            
            VStack(spacing: 0) {
                // 🚀 DÜZELTME: Sembol sütunu 160'a çıkarıldı.
                HStack {
                    Text("Tarih").frame(width: 60, alignment: .leading)
                    Text("Sembol").frame(width: 160, alignment: .leading)
                    Text("Adet").frame(width: 40, alignment: .leading)
                    Text("Satış Kuru").frame(width: 60, alignment: .trailing)
                    Spacer()
                    Text("Beyana Tabi Kazanç").frame(width: 120, alignment: .trailing)
                }.font(.system(size: 10, weight: .bold)).foregroundColor(.white).padding(8).background(Color(hex: "0D1425"))
                
                ForEach(Array(gains.enumerated()), id: \.offset) { index, gain in
                    HStack {
                        Text(formatDate(gain.sellDate)).frame(width: 60, alignment: .leading)
                        
                        // 🚀 DÜZELTME: minimumScaleFactor 0.9 yapıldı, width 160 oldu.
                        Text(gain.ticker)
                            .font(.system(size: 10, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                            .frame(width: 160, alignment: .leading)
                        
                        Text(String(format: "%g", gain.quantity)).frame(width: 40, alignment: .leading)
                        Text(String(format: "%.4f", gain.sellFxRate)).frame(width: 60, alignment: .trailing)
                        Spacer()
                        
                        Text(formatCurrency(gain.profitTL))
                            .foregroundColor(gain.profitTL >= 0 ? .black : .red)
                            .font(.system(size: 10, weight: .bold))
                            .frame(width: 120, alignment: .trailing)
                            
                    }.font(.system(size: 10)).padding(8).background(index % 2 == 0 ? Color.white : Color(white: 0.97))
                    Divider().background(Color.gray.opacity(0.1))
                }
            }.clipShape(RoundedRectangle(cornerRadius: 6)).overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2), lineWidth: 1))
        }
    }
    
    private func formatDate(_ date: Date) -> String { let f = DateFormatter(); f.dateFormat = "dd.MM.yy"; return f.string(from: date) }
    private func formatCurrency(_ value: Double) -> String { let f = NumberFormatter(); f.numberStyle = .decimal; f.maximumFractionDigits = 2; f.minimumFractionDigits = 2; return (f.string(from: NSNumber(value: value)) ?? "0") + " ₺" }
}

struct PDFDividendsTable: View {
    let transactions: [TradeTransaction]; let showTitle: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showTitle { Text("B. TEMETTÜ VE DİĞER GELİRLER").font(.system(size: 12, weight: .bold)).foregroundColor(Color(hex: "1F5EFF")).padding(.top, 10) }
            VStack(spacing: 0) {
                // 🚀 DÜZELTME: Sembol sütunu 160'a çıkarıldı.
                HStack {
                    Text("Tarih").frame(width: 60, alignment: .leading)
                    Text("Sembol").frame(width: 160, alignment: .leading)
                    Text("Tür").frame(width: 50, alignment: .leading)
                    Text("Brüt ($)").frame(width: 60, alignment: .trailing)
                    Text("Kur").frame(width: 50, alignment: .trailing)
                    Spacer()
                    Text("Brüt (TL)").frame(width: 90, alignment: .trailing)
                }.font(.system(size: 10, weight: .bold)).foregroundColor(.white).padding(8).background(Color(hex: "0D1425"))
                
                ForEach(Array(transactions.enumerated()), id: \.offset) { index, tx in
                    HStack {
                        Text(formatDate(tx.date)).frame(width: 60, alignment: .leading)
                        
                        // 🚀 DÜZELTME: minimumScaleFactor 0.9 yapıldı, width 160 oldu.
                        Text(tx.type == .other ? "-" : tx.ticker)
                            .font(.system(size: 10, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                            .frame(width: 160, alignment: .leading)
                            
                        Text(tx.type == .dividend ? "Temettü" : "Diğer").frame(width: 50, alignment: .leading)
                        Text("$\(String(format: "%.2f", tx.priceUSD))").frame(width: 60, alignment: .trailing)
                        Text(String(format: "%.4f", tx.fxRate)).frame(width: 50, alignment: .trailing)
                        Spacer()
                        Text(formatCurrency(tx.priceUSD * tx.fxRate)).frame(width: 90, alignment: .trailing)
                    }.font(.system(size: 10)).padding(8).background(index % 2 == 0 ? Color.white : Color(white: 0.97))
                    Divider().background(Color.gray.opacity(0.1))
                }
            }.clipShape(RoundedRectangle(cornerRadius: 6)).overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2), lineWidth: 1))
        }
    }
    private func formatDate(_ date: Date) -> String { let f = DateFormatter(); f.dateFormat = "dd.MM.yy"; return f.string(from: date) }
    private func formatCurrency(_ value: Double) -> String { let f = NumberFormatter(); f.numberStyle = .decimal; f.maximumFractionDigits = 2; f.minimumFractionDigits = 2; return (f.string(from: NSNumber(value: value)) ?? "0") + " ₺" }
}

struct PDFFooter: View {
    let pageNum: Int; let totalPages: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            Text("NOT: Bu rapordaki matrahlar; FIFO yöntemiyle, aracı kurum komisyon giderleri düşülerek ve kanuni Yİ-ÜFE enflasyon endekslemesi uygulanarak net olarak hesaplanmıştır.")
                .font(.system(size: 8))
                .foregroundColor(.gray)
                .padding(.bottom, 2)
            
            HStack {
                Text("YASAL UYARI: Bu rapor bilgilendirme amacı taşır. Çeşitli etkenlere bağlı olarak hesaplamalarda farklılıklar olabilir.")
                    .font(.system(size: 8))
                    .foregroundColor(.gray)
                Spacer()
                Text("Sayfa \(pageNum) / \(totalPages)").font(.system(size: 9, weight: .bold)).foregroundColor(.gray)
            }
        }
    }
}

// MARK: - 3. RENDER MOTORU
@MainActor
class PDFManager {
    static func render(year: String, userName: String, transactions: [TradeTransaction], gains: [RealizedGain], summary: TaxSummary, advisorFirmName: String? = nil) -> URL? {
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Vergi_Raporu_\(year).pdf")
        var pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4
        guard let pdfContext = CGContext(tempURL as CFURL, mediaBox: &pageRect, nil) else { return nil }
        
        let cappedGains = gains.map { gain -> RealizedGain in
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
            
            var modifiedGain = gain
            modifiedGain.profitTL = effectiveShieldedProfit
            modifiedGain.inflationAdjustmentTL = effectiveAdjustment
            return modifiedGain
        }
        
        let stockProfit = max(0, summary.netProfit)
        let inflationAdv = summary.inflationAdvantage
        let taxBase = summary.taxBase
        let totalTax = summary.totalTax
        let dividendTotal = summary.dividendTotal
        let otherTotal = summary.otherIncome
        let foreignTax = summary.foreignTaxCredit
        
        let dividends = transactions.filter { $0.type == .dividend || $0.type == .other }
        
        let firstPageGainsCount = min(cappedGains.count, 12)
        let firstPageGains = Array(cappedGains.prefix(firstPageGainsCount))
        let remainingGains = Array(cappedGains.dropFirst(firstPageGainsCount))
        
        let gainsChunks = remainingGains.chunked(into: 18)
        let divChunks = dividends.chunked(into: 18)
        
        let totalPages = 1 + gainsChunks.count + divChunks.count
        var currentPage = 1
        
        // --- SAYFA 1 ---
        pdfContext.beginPDFPage(nil)
        let page1View = VStack(alignment: .leading, spacing: 20) {
            PDFHeader(year: year, userName: userName, advisorFirmName: advisorFirmName)
            Divider()
            PDFSummaryDashboard(taxBase: taxBase, totalTax: totalTax, stockProfit: stockProfit, dividend: dividendTotal, otherIncome: otherTotal, foreignTax: foreignTax, inflationAdvantage: inflationAdv)
            
            if !firstPageGains.isEmpty {
                PDFGainsTable(gains: firstPageGains, showTitle: true)
            } else if !dividends.isEmpty {
                PDFDividendsTable(transactions: Array(dividends.prefix(12)), showTitle: true)
            }
            
            Spacer()
            PDFFooter(pageNum: currentPage, totalPages: totalPages)
        }.padding(40).frame(width: 595.2, height: 841.8).background(Color.white)
        
        let p1Renderer = ImageRenderer(content: page1View)
        p1Renderer.render { _, draw in draw(pdfContext) }
        pdfContext.endPDFPage()
        currentPage += 1
        
        // --- SAYFA 2+ (HİSSELER) ---
        for chunk in gainsChunks {
            pdfContext.beginPDFPage(nil)
            let gainsPage = VStack(alignment: .leading, spacing: 20) {
                PDFHeader(year: year, userName: userName, advisorFirmName: advisorFirmName)
                PDFGainsTable(gains: chunk, showTitle: true)
                Spacer()
                PDFFooter(pageNum: currentPage, totalPages: totalPages)
            }.padding(40).frame(width: 595.2, height: 841.8).background(Color.white)
            
            let gRenderer = ImageRenderer(content: gainsPage)
            gRenderer.render { _, draw in draw(pdfContext) }
            pdfContext.endPDFPage()
            currentPage += 1
        }
        
        // --- SAYFA X+ (TEMETTÜ) ---
        var finalDivChunks = divChunks
        if cappedGains.isEmpty && !dividends.isEmpty {
            let remainingDivs = Array(dividends.dropFirst(12))
            finalDivChunks = remainingDivs.chunked(into: 18)
        }
        
        for chunk in finalDivChunks {
            pdfContext.beginPDFPage(nil)
            let divPage = VStack(alignment: .leading, spacing: 20) {
                PDFHeader(year: year, userName: userName, advisorFirmName: advisorFirmName)
                PDFDividendsTable(transactions: chunk, showTitle: true)
                Spacer()
                PDFFooter(pageNum: currentPage, totalPages: totalPages)
            }.padding(40).frame(width: 595.2, height: 841.8).background(Color.white)
            
            let dRenderer = ImageRenderer(content: divPage)
            dRenderer.render { _, draw in draw(pdfContext) }
            pdfContext.endPDFPage()
            currentPage += 1
        }
        
        pdfContext.closePDF()
        return tempURL
    }
}

// MARK: - PAYLAŞIM EKRANI
struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
