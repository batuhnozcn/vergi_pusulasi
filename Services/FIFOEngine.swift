import Foundation

struct BuyLot {
    let transaction: TradeTransaction
    var remainingQuantity: Double
}

class FIFOEngine {
    
    // MEVCUT KÂR HESAPLAMA MOTORU (Dokunulmadı, Stabil)
    static func calculateGains(from transactions: [TradeTransaction]) -> [RealizedGain] {
        var realizedGains: [RealizedGain] = []
        let tickers = Set(transactions.map { $0.ticker })
        
        for ticker in tickers {
            let tickerTransactions = transactions
                .filter { $0.ticker == ticker }
                .sorted {
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
                        
                        let nominalCost = buyCostTL + buyCommissionTL
                        var totalCost = nominalCost
                        
                        if let buyIndex = YIUFEEngine.getIndex(for: buyTx.date),
                           let sellIndex = YIUFEEngine.getIndex(for: tx.date) {
                            let increaseRatio = (sellIndex - buyIndex) / buyIndex
                            if increaseRatio >= 0.10 {
                                totalCost = nominalCost * (1.0 + increaseRatio)
                            }
                        }
                        
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
    
    // 🚀 GÜNCELLENDİ: AÇIK POZİSYON HESAPLAMA (Komisyonlar Maliyete Eklendi)
    static func calculateOpenPositions(from transactions: [TradeTransaction]) -> [OpenPosition] {
        var openPositions: [OpenPosition] = []
        let tickers = Set(transactions.map { $0.ticker })
        
        for ticker in tickers {
            let tickerTransactions = transactions
                .filter { $0.ticker == ticker }
                .sorted { $0.date < $1.date }
            
            var buyLots: [BuyLot] = []
            
            for tx in tickerTransactions {
                if tx.type == .buy {
                    buyLots.append(BuyLot(transaction: tx, remainingQuantity: tx.quantity))
                } else if tx.type == .sell {
                    var remainingSellQty = tx.quantity
                    for i in 0..<buyLots.count {
                        if remainingSellQty <= 0 { break }
                        let matchedQty = min(buyLots[i].remainingQuantity, remainingSellQty)
                        buyLots[i].remainingQuantity -= matchedQty
                        remainingSellQty -= matchedQty
                    }
                }
            }
            
            let activeLots = buyLots.filter { $0.remainingQuantity > 0.000001 }
            if !activeLots.isEmpty {
                let totalQty = activeLots.reduce(0.0) { $0 + $1.remainingQuantity }
                
                // Komisyonlar, hisse oranına göre hesaplanıp maliyete yediriliyor
                let totalCostUSD = activeLots.reduce(0.0) { sum, lot in
                    let proportion = lot.remainingQuantity / lot.transaction.quantity
                    let cost = lot.remainingQuantity * lot.transaction.priceUSD
                    let comm = lot.transaction.commissionUSD * proportion
                    return sum + cost + comm
                }
                
                openPositions.append(OpenPosition(
                    ticker: ticker,
                    totalQuantity: totalQty,
                    averageCostUSD: totalCostUSD / totalQty,
                    firstBuyDate: activeLots.first?.transaction.date ?? Date()
                ))
            }
        }
        return openPositions.sorted { $0.ticker < $1.ticker }
    }
}
