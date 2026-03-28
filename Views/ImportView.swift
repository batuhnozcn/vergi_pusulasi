import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import FirebaseAuth

enum BrokerType {
    case midas
    case ibkr
    case template
    case generic
}

struct ImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    
    @State private var showDocumentPicker = false
    @State private var isProcessing = false
    @State private var parsedItems: [TradeTransaction] = []
    @State private var successCount = 0
    @State private var failCount = 0
    @State private var showSuccessAlert = false
    
    // 🚀 YENİ: Dosya indirme durumu ve şablonumuz
    @State private var showExporter = false
    @State private var templateDocument = CSVDocument(initialText: "Tarih,İşlem Tipi,Sembol,Adet,Fiyat,Komisyon\n15.03.2026,Alış,AAPL,10,150.50,1.5\n20.03.2026,Satış,TSLA,5,200.00,2.0\n01.04.2026,Temettü,MSFT,1,5.50,0.5")
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("İşlemlerinizi Otomatik").font(.system(size: 28, weight: .bold, design: .rounded)).foregroundColor(.primary)
                            Text("İçe Aktarın").font(.system(size: 28, weight: .bold, design: .rounded)).foregroundColor(Color(hex: "1F5EFF"))
                            Text("Vergi hesaplaması için standart şablonumuzu kullanarak işlemlerinizi saniyeler içinde yükleyin.").font(.system(size: 15)).foregroundColor(.secondary).lineSpacing(4).padding(.top, 4)
                        }.padding(.horizontal, 24).padding(.top, 16)
                        
                        VStack(spacing: 16) {
                            Circle().fill(Color(hex: "1F5EFF").opacity(0.1)).frame(width: 80, height: 80).overlay(Image(systemName: "doc.text.fill").font(.system(size: 32)).foregroundColor(Color(hex: "1F5EFF")))
                            
                            VStack(spacing: 8) { Text("Dosya Seçin").font(.system(size: 20, weight: .bold)).foregroundColor(.primary); Text("Cihazınızdaki CSV veya TXT dosyasını seçerek başlayın.").font(.system(size: 14)).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal, 20) }
                            
                            Button(action: { showDocumentPicker = true }) {
                                HStack {
                                    if isProcessing { ProgressView().tint(.white).padding(.trailing, 4); Text("İşleniyor...") }
                                    else { Text("Gözat") }
                                }.font(.system(size: 16, weight: .bold)).foregroundColor(.white).frame(width: 140).padding(.vertical, 14).background(Color(hex: "1F5EFF")).clipShape(Capsule()).shadow(color: Color(hex: "1F5EFF").opacity(0.3), radius: 8, y: 4)
                            }.padding(.top, 8).disabled(isProcessing)
                        }.padding(.vertical, 32).frame(maxWidth: .infinity).background(Color(UIColor.secondarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [8])).foregroundColor(Color.gray.opacity(0.2))).padding(.horizontal, 24)
                        
                        if !parsedItems.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack { Text("Önizleme").font(.system(size: 18, weight: .bold)).foregroundColor(.primary); Spacer(); Text("\(parsedItems.count) İşlem Bulundu").font(.system(size: 12, weight: .bold)).foregroundColor(.green).padding(.horizontal, 10).padding(.vertical, 4).background(Color.green.opacity(0.1)).clipShape(Capsule()) }.padding(.horizontal, 24)
                                if failCount > 0 { HStack { Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange); Text("\(failCount) satır okunamadığı için atlandı.").font(.system(size: 13, weight: .medium)).foregroundColor(.orange) }.padding(.horizontal, 24) }
                                VStack(spacing: 12) { ForEach(parsedItems.prefix(10)) { item in ImportPreviewRow(item: item) }; if parsedItems.count > 10 { Text("+ \(parsedItems.count - 10) işlem daha...").font(.system(size: 13, weight: .medium)).foregroundColor(.secondary).padding(.top, 8) } }.padding(.horizontal, 24)
                                Button(action: saveImportedItems) { HStack { Image(systemName: "checkmark.circle.fill"); Text("Tümünü Kaydet") }.font(.system(size: 16, weight: .bold)).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 16).background(Color.green).clipShape(RoundedRectangle(cornerRadius: 16)).shadow(color: Color.green.opacity(0.3), radius: 10, y: 5) }.padding(.horizontal, 24).padding(.top, 8)
                            }
                        }
                        
                        if parsedItems.isEmpty {
                            VStack(alignment: .leading, spacing: 20) {
                                Text("NASIL ÇALIŞIR?").font(.system(size: 12, weight: .bold)).foregroundColor(.secondary).padding(.horizontal, 24)
                                
                                VStack(spacing: 20) {
                                    StepRow(number: "1", title: "Şablonu İndirin", subtitle: "Aşağıdaki butona tıklayarak standart CSV şablonumuzu cihazınıza kaydedin.")
                                    StepRow(number: "2", title: "Verilerinizi Kopyalayın", subtitle: "Aracı kurumunuzdan aldığınız verileri şablondaki sütunlara uygun şekilde yapıştırın.")
                                    StepRow(number: "3", title: "Sisteme Yükleyin", subtitle: "Hazırladığınız dosyayı yukarıdaki 'Gözat' butonundan seçerek saniyeler içinde içe aktarın.")
                                }.padding(.horizontal, 24)
                                
                                Button(action: { showExporter = true }) {
                                    HStack {
                                        Image(systemName: "square.and.arrow.down")
                                        Text("Örnek CSV Şablonunu İndir")
                                    }
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(Color(hex: "1F5EFF"))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color(hex: "1F5EFF").opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                }.padding(.horizontal, 24).padding(.top, 8)
                            }.padding(.top, 8)
                        }
                        
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle("Veri Aktarımı")
            .navigationBarTitleDisplayMode(.inline)
            .alert("İşlem Başarılı", isPresented: $showSuccessAlert) {
                Button("Tamam", role: .cancel) { NotificationCenter.default.post(name: NSNotification.Name("DismissModalAndGoHome"), object: nil) }
            } message: {
                Text("\(parsedItems.count) adet işlem başarıyla veritabanına kaydedildi.")
            }
            .fileImporter(isPresented: $showDocumentPicker, allowedContentTypes: [.item, .text, .data, .commaSeparatedText], allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls): if let url = urls.first { processCSV(url: url) }
                case .failure(let error): print("Dosya seçme hatası: \(error.localizedDescription)")
                }
            }
            .fileExporter(
                isPresented: $showExporter,
                document: templateDocument,
                contentType: .commaSeparatedText,
                defaultFilename: "VergiPusulasi_Sablon"
            ) { result in
                switch result {
                case .success(let url): print("Şablon başarıyla kaydedildi: \(url)")
                case .failure(let error): print("Şablon kaydedilemedi: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // 🚀 ÇÖZÜM: Türkçe Karakter Sorunu (İ ve I) zırhlanarak çözüldü
    private func detectBroker(headerRow: String) -> BrokerType {
        let lowerHeader = headerRow.lowercased()
            .replacingOccurrences(of: "i̇", with: "i") // Büyük İ harfi hatasını giderir
            .replacingOccurrences(of: "ı", with: "i") // Büyük I harfi hatasını giderir
        
        if (lowerHeader.contains("islem") || lowerHeader.contains("işlem")) && lowerHeader.contains("sembol") && lowerHeader.contains("fiyat") {
            if lowerHeader.contains("komisyon") { return .template }
            return .midas
        }
        if lowerHeader.contains("asset category") || lowerHeader.contains("ibkr") || lowerHeader.contains("trade") { return .ibkr }
        return .generic
    }
    
    private func processCSV(url: URL) {
        isProcessing = true; parsedItems.removeAll(); successCount = 0; failCount = 0
        guard url.startAccessingSecurityScopedResource() else { isProcessing = false; return }
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let fileContent = try String(contentsOf: url, encoding: .utf8)
            let rawRows = fileContent.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            
            guard let headerRow = rawRows.first else { throw NSError(domain: "EmptyFile", code: 1, userInfo: nil) }
            let broker = detectBroker(headerRow: headerRow)
            
            var tempItems: [TradeTransaction] = []
            
            for index in 1..<rawRows.count {
                let row = rawRows[index]
                let separator: Character = row.contains(";") ? ";" : ","
                let columns = row.split(separator: separator, omittingEmptySubsequences: false).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "") }
                
                if let item = parseSmartRow(columns: columns, broker: broker) {
                    tempItems.append(item)
                    successCount += 1
                } else { failCount += 1 }
            }
            
            Task {
                let datesToFetch = tempItems.filter { $0.fxRate == 0 }.map { $0.date }
                if !datesToFetch.isEmpty { await TCMBService.shared.preFetchRates(for: datesToFetch) }
                
                for i in 0..<tempItems.count {
                    if tempItems[i].fxRate == 0 {
                        if let rate = await TCMBService.shared.fetchRate(for: tempItems[i].date) { tempItems[i].fxRate = rate }
                    }
                }
                
                await MainActor.run {
                    self.parsedItems = tempItems
                    self.isProcessing = false
                }
            }
            
        } catch {
            print("Dosya okunamadı: \(error)")
            isProcessing = false
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    private func parseSmartRow(columns: [String], broker: BrokerType) -> TradeTransaction? {
        var date: Date?
        var ticker = ""
        var tradeType: TradeType = .buy
        var quantity: Double = 0
        var priceUSD: Double = 0
        var commissionUSD: Double = 0
        var csvFxRate: Double = 0.0
        let formatter = DateFormatter()
        
        switch broker {
        case .template:
            guard columns.count >= 5 else { return nil }
            formatter.dateFormat = "dd.MM.yyyy"
            date = formatter.date(from: columns[0])
            ticker = columns[2].uppercased()
            
            let typeStr = columns[1].lowercased()
                .replacingOccurrences(of: "i̇", with: "i")
                .replacingOccurrences(of: "ı", with: "i")
            
            if typeStr.contains("sat") { tradeType = .sell }
            else if typeStr.contains("temet") { tradeType = .dividend }
            else if typeStr.contains("diğ") || typeStr.contains("dig") { tradeType = .other }
            else { tradeType = .buy }
            
            quantity = Double(columns[3].replacingOccurrences(of: ",", with: ".")) ?? 1.0
            priceUSD = Double(columns[4].replacingOccurrences(of: ",", with: ".")) ?? 0.0
            if columns.count >= 6 { commissionUSD = Double(columns[5].replacingOccurrences(of: ",", with: ".")) ?? 0.0 }
            
        case .midas:
            guard columns.count >= 5 else { return nil }
            formatter.dateFormat = "dd.MM.yyyy"
            date = formatter.date(from: columns[0])
            ticker = columns[2].uppercased()
            let typeStr = columns[1].lowercased()
            if typeStr.contains("satış") { tradeType = .sell }
            else if typeStr.contains("temettü") { tradeType = .dividend }
            quantity = Double(columns[3].replacingOccurrences(of: ",", with: ".")) ?? 1.0
            priceUSD = Double(columns[4].replacingOccurrences(of: ",", with: ".")) ?? 0.0
            if columns.count >= 6 { commissionUSD = Double(columns[5].replacingOccurrences(of: ",", with: ".")) ?? 0.0 }
            
        case .ibkr:
            guard columns.count >= 5 else { return nil }
            formatter.dateFormat = "yyyy-MM-dd"
            ticker = columns[0].uppercased()
            date = formatter.date(from: columns[1].prefix(10).description)
            let typeStr = columns[2].lowercased()
            if typeStr.contains("sell") || typeStr == "s" { tradeType = .sell }
            else if typeStr.contains("dividend") || typeStr == "div" { tradeType = .dividend }
            quantity = abs(Double(columns[3].replacingOccurrences(of: ",", with: ".")) ?? 1.0)
            priceUSD = Double(columns[4].replacingOccurrences(of: ",", with: ".")) ?? 0.0
            if columns.count >= 6 { commissionUSD = abs(Double(columns[5].replacingOccurrences(of: ",", with: ".")) ?? 0.0) }
            
        case .generic:
            guard columns.count >= 5 else { return nil }
            formatter.dateFormat = "yyyy-MM-dd"
            var parsedDate = formatter.date(from: columns[0])
            if parsedDate == nil {
                formatter.dateFormat = "dd.MM.yyyy"
                parsedDate = formatter.date(from: columns[0])
            }
            date = parsedDate
            
            let col1 = columns[1].trimmingCharacters(in: .whitespaces).lowercased()
            let col2 = columns[2].trimmingCharacters(in: .whitespaces).lowercased()
            let typeKeywords = ["alis", "alış", "satis", "satış", "temettu", "temettü", "diger", "diğer", "buy", "sell", "div"]
            
            let typeStr: String
            if typeKeywords.contains(where: { col1.contains($0) }) {
                typeStr = col1; ticker = columns[2].trimmingCharacters(in: .whitespaces).uppercased()
            } else {
                typeStr = col2; ticker = columns[1].trimmingCharacters(in: .whitespaces).uppercased()
            }
            
            quantity = Double(columns[3].replacingOccurrences(of: ",", with: ".")) ?? 1.0
            priceUSD = Double(columns[4].replacingOccurrences(of: ",", with: ".")) ?? 0.0
            
            if typeStr.contains("sat") || typeStr.contains("sell") { tradeType = .sell }
            else if typeStr.contains("temet") || typeStr.contains("div") { tradeType = .dividend }
            else if typeStr.contains("diğ") || typeStr.contains("dig") || typeStr.contains("oth") { tradeType = .other }
            else { tradeType = .buy }
            
            if columns.count >= 7 {
                let val1 = Double(columns[5].replacingOccurrences(of: ",", with: ".")) ?? 0.0
                let val2 = Double(columns[6].replacingOccurrences(of: ",", with: ".")) ?? 0.0
                if val1 > 15.0 && val2 < 15.0 { csvFxRate = val1; commissionUSD = val2 }
                else if val2 > 15.0 && val1 < 15.0 { csvFxRate = val2; commissionUSD = val1 }
                else { commissionUSD = val1; csvFxRate = val2 }
            } else if columns.count == 6 {
                csvFxRate = Double(columns[5].replacingOccurrences(of: ",", with: ".")) ?? 0.0
            }
        }
        
        guard let validDate = date, priceUSD > 0, !ticker.isEmpty else { return nil }
        
        // 🚀 ÇÖZÜM: OPSIYON ÇARPANI (1 Sözleşme = 100 Hisse)
        // Eğer sembol (ticker) içinde rakam varsa (Örn: ORCL251128C00240000) bu bir opsiyondur.
        if ticker.rangeOfCharacter(from: .decimalDigits) != nil && ticker.count > 5 {
            quantity = quantity * 100
        }
        
        return TradeTransaction(ticker: ticker, type: tradeType, quantity: quantity, priceUSD: priceUSD, commissionUSD: commissionUSD, date: validDate, fxRate: csvFxRate)
    }
    
    private func saveImportedItems() {
        let itemsToSave = parsedItems
        let currentUserId = Auth.auth().currentUser?.uid ?? ""
        
        for item in itemsToSave { item.userId = currentUserId; modelContext.insert(item) }
        
        Task {
            for item in itemsToSave { do { try await FirebaseManager.shared.saveTransaction(item) } catch { print("Bulut hatası: \(error)") } }
            await MainActor.run { UINotificationFeedbackGenerator().notificationOccurred(.success); showSuccessAlert = true }
        }
    }
}

struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    var text: String
    
    init(initialText: String = "") { self.text = initialText }
    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents, let string = String(data: data, encoding: .utf8) { text = string } else { throw CocoaError(.fileReadCorruptFile) }
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        var data = Data([0xEF, 0xBB, 0xBF])
        if let textData = text.data(using: .utf8) { data.append(textData) }
        return .init(regularFileWithContents: data)
    }
}

struct StepRow: View {
    let number: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle().fill(Color(hex: "1F5EFF").opacity(0.1)).frame(width: 32, height: 32)
                Text(number).font(.system(size: 14, weight: .bold)).foregroundColor(Color(hex: "1F5EFF"))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 15, weight: .bold)).foregroundColor(.primary)
                Text(subtitle).font(.system(size: 13)).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true).lineSpacing(2)
            }
            Spacer()
        }
    }
}

struct ImportPreviewRow: View { let item: TradeTransaction; var body: some View { HStack(spacing: 12) { ZStack { Circle().fill(iconColor.opacity(0.1)).frame(width: 36, height: 36); if item.type == .buy || item.type == .sell { Text(item.ticker.isEmpty ? "St" : String(item.ticker.prefix(3))).font(.system(size: 10, weight: .bold)).foregroundColor(iconColor) } else { Image(systemName: iconName).font(.system(size: 14, weight: .bold)).foregroundColor(iconColor) } }; VStack(alignment: .leading, spacing: 2) { Text(item.type == .sell ? "\(item.ticker) Satışı" : (item.type == .dividend ? "\(item.ticker) Temettü" : (item.type == .other ? "Diğer Gelir" : "Alış İşlemi"))).font(.system(size: 14, weight: .bold)).foregroundColor(.primary); Text("Tarih: \(formatDate(item.date)) • Kur: \(item.fxRate > 0 ? String(format: "%.2f", item.fxRate) : "---")").font(.system(size: 11)).foregroundColor(.secondary) }; Spacer(); Text("$\(String(format: "%.2f", item.priceUSD * item.quantity))").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(item.priceUSD >= 0 ? .primary : .red) }.padding(12).background(Color(UIColor.secondarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 12)).shadow(color: .black.opacity(0.02), radius: 5, y: 2) }; var iconColor: Color { item.type == .sell ? .blue : (item.type == .dividend ? .green : .orange) }; var iconName: String { item.type == .sell ? "arrow.up.right" : (item.type == .dividend ? "dollarsign.circle.fill" : "arrow.down.left") }; private func formatDate(_ date: Date) -> String { let f = DateFormatter(); f.dateFormat = "dd.MM.yyyy"; return f.string(from: date) } }
