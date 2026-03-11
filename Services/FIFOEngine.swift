import Foundation

struct BuyLot {
    let transaction: TradeTransaction
    var remainingQuantity: Double
}

class FIFOEngine {
    
    static func calculateGains(from transactions: [TradeTransaction]) -> [RealizedGain] {
        var realizedGains: [RealizedGain] = []
        let tickers = Set(transactions.map { $0.ticker })
        
        for ticker in tickers {
            let tickerTransactions = transactions
                .filter { $0.ticker == ticker }
                .sorted {
                    // 🚨 YENİ ÇÖZÜM (Madde 4): Aynı gün işlemlerinde Alış her zaman Satıştan önce gelir
                    if Calendar.current.isDate($0.date, inSameDayAs: $1.date) {
                        if $0.type == .buy && $1.type != .buy { return true }
                        if $0.type != .buy && $1.type == .buy { return false }
                    }
                    return $0.date < $1.date
                }
            
            var buyLots: [BuyLot] = []
            
            for tx in tickerTransactions {
                if tx.type == .buy {
                    buyLots.append(BuyLot(transaction: tx, remainingQuantity: tx.quantity))
                } else if tx.type == .sell {
                    var remainingSellQty = tx.quantity
                    
                    for i in 0..<buyLots.count {
                        if remainingSellQty <= 0 { break }
                        if buyLots[i].remainingQuantity <= 0 { continue }
                        
                        let buyTx = buyLots[i].transaction
                        if buyTx.date > tx.date { continue }
                        
                        let matchedQty = min(buyLots[i].remainingQuantity, remainingSellQty)
                        
                        let buyProportion = matchedQty / buyTx.quantity
                        let sellProportion = matchedQty / tx.quantity
                        
                        let buyCostTL = matchedQty * buyTx.priceUSD * buyTx.fxRate
                        let buyCommissionTL = (buyTx.commissionUSD * buyProportion) * buyTx.fxRate
                        
                        // Orijinal Maliyet
                        let nominalCost = buyCostTL + buyCommissionTL
                        var totalCost = nominalCost
                        
                        // Yİ-ÜFE ENDEKSLEME KURALI
                        if let buyIndex = YIUFEEngine.getIndex(for: buyTx.date),
                           let sellIndex = YIUFEEngine.getIndex(for: tx.date) {
                            
                            let increaseRatio = (sellIndex - buyIndex) / buyIndex
                            
                            // %10 Artış Kuralı
                            if increaseRatio >= 0.10 {
                                totalCost = nominalCost * (1.0 + increaseRatio)
                            }
                        }
                        
                        // SAĞLANAN AVANTAJ HESAPLANIYOR
                        let inflationAdjustmentTL = totalCost - nominalCost
                        
                        let sellRevenueTL = matchedQty * tx.priceUSD * tx.fxRate
                        let sellCommissionTL = (tx.commissionUSD * sellProportion) * tx.fxRate
                        let totalRevenue = sellRevenueTL - sellCommissionTL
                        
                        let profitTL = totalRevenue - totalCost
                        
                        let gain = RealizedGain(
                            ticker: ticker,
                            quantity: matchedQty,
                            buyDate: buyTx.date,
                            sellDate: tx.date,
                            buyPriceUSD: buyTx.priceUSD,
                            sellPriceUSD: tx.priceUSD,
                            buyFxRate: buyTx.fxRate,
                            sellFxRate: tx.fxRate,
                            profitTL: profitTL,
                            inflationAdjustmentTL: inflationAdjustmentTL
                        )
                        
                        realizedGains.append(gain)
                        
                        buyLots[i].remainingQuantity -= matchedQty
                        remainingSellQty -= matchedQty
                    }
                }
            }
        }
        
        return realizedGains.sorted { $0.sellDate > $1.sellDate }
    }
}
