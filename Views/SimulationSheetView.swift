import SwiftUI

struct SimulationSheetView: View {
    let position: OpenPosition
    let allTransactions: [TradeTransaction]
    
    @State private var targetPriceUSD: Double? = nil
    @State private var liveFxRate: Double? = nil
    @State private var isLoading = true
    @State private var manualPriceInput: String = ""
    
    // 🚀 YENİ: Merkezi servisin ihtiyaç duyduğu Premium durumunu AppStorage'dan çekiyoruz
    @AppStorage("isPremium") private var isPremium = false
    
    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView("Canlı piyasa verileri çekiliyor...")
                            .padding()
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                } else {
                    // 1. BÖLÜM: HİSSE BİLGİSİ
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(position.ticker).font(.system(size: 34, weight: .heavy, design: .rounded))
                            
                            HStack(alignment: .firstTextBaseline) {
                                Text("$\(String(format: "%.2f", targetPriceUSD ?? 0))")
                                    .font(.title3.bold())
                                Text("Anlık Fiyat")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text("\(String(format: "%.2f", position.totalQuantity)) Adet • Ort. Maliyet: $\(String(format: "%.2f", position.averageCostUSD))")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // 2. BÖLÜM: BÜYÜK RESİM (VERGİ ETKİSİ)
                    if let price = targetPriceUSD, let fx = liveFxRate {
                        let comparison = calculateTaxImpact(simulatedPrice: price, simulatedFx: fx)
                        
                        Section(header: Text("Vergi Yüküne Etkisi")) {
                            HStack {
                                Text("Mevcut Tahmini Vergi")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(formatCurrency(comparison.currentTax))
                                    .fontWeight(.medium)
                            }
                            
                            HStack {
                                Text("Satış Sonrası Yeni Vergi")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(formatCurrency(comparison.newTax))
                                    .fontWeight(.bold)
                            }
                            
                            HStack {
                                Text("Fark (Ek Vergi Yükü)")
                                    .font(.headline)
                                Spacer()
                                Text(comparison.taxDifference > 0 ? "+\(formatCurrency(comparison.taxDifference))" : formatCurrency(comparison.taxDifference))
                                    .font(.title3.bold())
                                    .foregroundColor(comparison.taxDifference > 0 ? .red : (comparison.taxDifference < 0 ? .green : .primary))
                            }
                            .padding(.vertical, 4)
                        }
                        
                        // Yİ-ÜFE Kalkanı varsa sade bir şekilde göster
                        if comparison.simulatedGain.inflationAdjustmentTL > 0 {
                            Section {
                                HStack(alignment: .top) {
                                    Image(systemName: "shield.fill").foregroundColor(.green)
                                        .padding(.top, 2)
                                    Text("Yİ-ÜFE Kalkanı Devrede: Bu satıştan elde edeceğiniz kârın \(formatCurrency(comparison.simulatedGain.inflationAdjustmentTL)) tutarındaki kısmı yasal olarak vergiden muaf tutuldu.")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                    
                    // 3. BÖLÜM: FARKLI BİR SENARYO
                    Section(header: Text("Farklı Bir Senaryo Dene"), footer: Text("Hisse fiyatı belirlediğiniz rakama ulaşırsa vergi yükünüzün nasıl etkileneceğini görebilirsiniz.")) {
                        HStack {
                            Text("Hedef Satış Fiyatı ($)")
                            Spacer()
                            TextField("0.00", text: $manualPriceInput)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .onChange(of: manualPriceInput) { oldValue, newValue in
                                    let cleanText = newValue.replacingOccurrences(of: ",", with: ".")
                                    if let newPrice = Double(cleanText) {
                                        targetPriceUSD = newPrice
                                    }
                                }
                        }
                    }
                }
            }
            .navigationTitle("Simülasyon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    // Sheet kapatma aksiyonu
                }
            }
        }
        .onAppear {
            runInitialFetch()
        }
    }
    
    // MARK: - MATEMATİK VE GÖLGE İŞLEM MOTORU
    private func calculateTaxImpact(simulatedPrice: Double, simulatedFx: Double) -> (currentTax: Double, newTax: Double, taxDifference: Double, simulatedGain: RealizedGain) {
        
        let currentYearInt = Calendar.current.component(.year, from: Date())
        let currentYearString = String(currentYearInt)
        
        // 1. Mevcut Durumu Hesapla (🚀 YENİ: Merkezi Servis Kullanılıyor)
        let currentGains = FIFOEngine.calculateGains(from: allTransactions).filter {
            String(Calendar.current.component(.year, from: $0.sellDate)) == currentYearString
        }
        let currentSummary = TaxComputationService.shared.calculateSummary(
            transactions: allTransactions,
            gains: currentGains,
            year: currentYearInt,
            isPremium: isPremium
        )
        let currentTax = currentSummary.totalTax
        
        // 2. Gölge İşlemi Sisteme Enjekte Et
        let shadowSell = TradeTransaction(
            ticker: position.ticker,
            type: .sell,
            quantity: position.totalQuantity,
            priceUSD: simulatedPrice,
            commissionUSD: 0,
            date: Date(),
            fxRate: simulatedFx
        )
        var simulationContext = allTransactions
        simulationContext.append(shadowSell)
        
        // 3. Yeni Durumu Hesapla (🚀 YENİ: Merkezi Servis Kullanılıyor)
        let newGains = FIFOEngine.calculateGains(from: simulationContext).filter {
            String(Calendar.current.component(.year, from: $0.sellDate)) == currentYearString
        }
        let newSummary = TaxComputationService.shared.calculateSummary(
            transactions: simulationContext,
            gains: newGains,
            year: currentYearInt,
            isPremium: isPremium
        )
        let newTax = newSummary.totalTax
        
        // Olası bir hata durumuna karşı boş model (Fallback)
        let emptyGain = RealizedGain(ticker: "", quantity: 0, buyDate: Date(), sellDate: Date(), buyPriceUSD: 0, sellPriceUSD: 0, buyFxRate: 0, sellFxRate: 0, profitTL: 0, inflationAdjustmentTL: 0)
        
        let simulatedGainForThisTicker = newGains.first { Calendar.current.isDateInToday($0.sellDate) && $0.ticker == position.ticker } ?? emptyGain
            
        return (currentTax, newTax, newTax - currentTax, simulatedGainForThisTicker)
    }
    
    // MARK: - AĞ ÇAĞRILARI
    private func runInitialFetch() {
        Task {
            async let fetchedFx = TCMBService.shared.fetchRate(for: Date())
            async let fetchedPrice = MarketDataService.shared.fetchLivePrice(for: position.ticker)
            
            let (fx, price) = await (fetchedFx, fetchedPrice)
            
            await MainActor.run {
                self.liveFxRate = fx ?? 33.50 // Kur çekilemezse geçici güvenlik değeri
                self.targetPriceUSD = price
                if let p = price {
                    self.manualPriceInput = String(format: "%.2f", p)
                }
                self.isLoading = false
            }
        }
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "₺"
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "₺0"
    }
}
