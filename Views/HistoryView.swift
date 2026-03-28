import SwiftUI
import SwiftData
import FirebaseAuth
import UIKit

enum TransactionFilter: String, CaseIterable {
    case all = "Tümü"
    case buy = "Alış"
    case sell = "Satış"
    case dividend = "Temettü"
}

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    
    // Veritabanındaki tüm işlemler
    @Query(sort: \TradeTransaction.date, order: .reverse) private var transactions: [TradeTransaction]
    
    // Filtreleme ve Firebase Auth Mantığı
    @State private var selectedFilter: TransactionFilter = .all
    @AppStorage("isBalanceHidden") private var isBalanceHidden = false
    
    // Seçme ve Silme Modu Değişkenleri
    @State private var isSelectionMode = false
    @State private var selectedTransactionIDs = Set<PersistentIdentifier>()
    @State private var transactionToDelete: TradeTransaction?
    @State private var showSingleDeleteAlert = false
    @State private var showBulkDeleteAlert = false
    
    // 🚀 DÜZELTME: Düzenleme sayfası için model bağlantısı
    @State private var transactionToEdit: TradeTransaction?
    
    // Sadece giriş yapan kullanıcının işlemleri
    var userTransactions: [TradeTransaction] {
        let currentUserId = Auth.auth().currentUser?.uid ?? ""
        return transactions.filter { $0.userId == currentUserId }
    }
    
    // Segmented Control (Picker) için filtrelenmiş liste
    var filteredTransactions: [TradeTransaction] {
        switch selectedFilter {
        case .all: return userTransactions
        case .buy: return userTransactions.filter { $0.type == .buy }
        case .sell: return userTransactions.filter { $0.type == .sell }
        case .dividend: return userTransactions.filter { $0.type == .dividend }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if !isSelectionMode {
                        Picker("Filtre", selection: $selectedFilter) {
                            ForEach(TransactionFilter.allCases, id: \.self) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    
                    if filteredTransactions.isEmpty {
                        Spacer()
                        emptyStateView
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            // 🚀 DÜZELTME: Bitişik liste yerine aralarında boşluk olan Kart (Card) tasarımı
                            LazyVStack(spacing: 12) {
                                ForEach(filteredTransactions) { item in
                                    HStack(spacing: 0) {
                                        // CHECKBOX
                                        if isSelectionMode {
                                            Image(systemName: selectedTransactionIDs.contains(item.persistentModelID) ? "checkmark.circle.fill" : "circle")
                                                .font(.system(size: 22))
                                                .foregroundColor(selectedTransactionIDs.contains(item.persistentModelID) ? Color(hex: "1F5EFF") : .secondary)
                                                .padding(.trailing, 12)
                                                .transition(.move(edge: .leading).combined(with: .opacity))
                                        }
                                        
                                        ModernTransactionRowContent(item: item)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    // 🚀 DÜZELTME: Her işlem artık bağımsız bir kart
                                    .background(Color(UIColor.secondarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
                                    // Çakışmayı önleyen özel dokunma alanı
                                    .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    
                                    // 🚀 YENİ UX: Artık uzun basmaya gerek yok, tek tıkla düzenleme açılır!
                                    .onTapGesture {
                                        let generator = UIImpactFeedbackGenerator(style: .light)
                                        generator.impactOccurred()
                                        
                                        if isSelectionMode {
                                            withAnimation(.snappy(duration: 0.2)) {
                                                if selectedTransactionIDs.contains(item.persistentModelID) {
                                                    selectedTransactionIDs.remove(item.persistentModelID)
                                                } else {
                                                    selectedTransactionIDs.insert(item.persistentModelID)
                                                }
                                            }
                                        } else {
                                            // Seçim modunda değilsek tek tıkla düzenleme ekranına git
                                            transactionToEdit = item
                                        }
                                    }
                                    // Uzun basmak isteyenler için klasik menü
                                    .contextMenu(isSelectionMode ? nil : ContextMenu {
                                        Button {
                                            transactionToEdit = item
                                        } label: { Label("Düzenle", systemImage: "pencil") }
                                        
                                        Button(role: .destructive) {
                                            transactionToDelete = item
                                            showSingleDeleteAlert = true
                                        } label: { Label("Sil", systemImage: "trash") }
                                    })
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                            .padding(.bottom, isSelectionMode ? 100 : 20)
                        }
                    }
                }
                
                // TOPLU SİLME BARI
                if isSelectionMode && !selectedTransactionIDs.isEmpty {
                    VStack {
                        Spacer()
                        HStack {
                            Text("\(selectedTransactionIDs.count) İşlem Seçildi")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Button(role: .destructive) {
                                let generator = UIImpactFeedbackGenerator(style: .heavy)
                                generator.impactOccurred()
                                showBulkDeleteAlert = true
                            } label: {
                                Text("Seçilenleri Sil")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.red)
                                    .cornerRadius(20)
                            }
                        }
                        .padding(20)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: Color.red.opacity(0.15), radius: 15, x: 0, y: 8)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle(isSelectionMode ? "İşlemleri Seç" : "Tüm İşlemler")
            .navigationBarTitleDisplayMode(.inline)
            
            // TOOLBAR
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isSelectionMode {
                        let allSelected = !filteredTransactions.isEmpty && selectedTransactionIDs.count == filteredTransactions.count
                        Button(allSelected ? "Seçimi Kaldır" : "Tümünü Seç") {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            withAnimation(.snappy(duration: 0.2)) {
                                if allSelected {
                                    selectedTransactionIDs.removeAll()
                                } else {
                                    selectedTransactionIDs = Set(filteredTransactions.map { $0.persistentModelID })
                                }
                            }
                        }
                        .tint(allSelected ? .primary : Color(hex: "1F5EFF"))
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSelectionMode ? "İptal" : "Seç") {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        withAnimation {
                            isSelectionMode.toggle()
                            selectedTransactionIDs.removeAll()
                        }
                    }
                    .tint(isSelectionMode ? .primary : Color(hex: "1F5EFF"))
                }
            }
            
            // --- ALERT VE SHEETLER ---
            .alert("İşlemi Sil", isPresented: $showSingleDeleteAlert, presenting: transactionToDelete) { item in
                Button("İptal", role: .cancel) { transactionToDelete = nil }
                Button("Sil", role: .destructive) {
                    let itemToDelete = item
                    withAnimation {
                        modelContext.delete(item)
                        try? modelContext.save()
                        transactionToDelete = nil
                    }
                    Task { do { try await FirebaseManager.shared.deleteTransaction(itemToDelete) } catch { print("Firebase silme hatası: \(error)") } }
                }
            } message: { item in
                Text("\(item.ticker) hissesine ait bu işlemi silmek istediğinize emin misiniz? Bu işlem geri alınamaz.")
            }
            .alert("\(selectedTransactionIDs.count) İşlemi Sil", isPresented: $showBulkDeleteAlert) {
                Button("İptal", role: .cancel) { }
                Button("Seçilenleri Sil", role: .destructive) {
                    let idsToDelete = selectedTransactionIDs
                    var itemsToDeleteFromCloud: [TradeTransaction] = []
                    
                    withAnimation {
                        for itemID in idsToDelete {
                            if let model = modelContext.model(for: itemID) as? TradeTransaction {
                                itemsToDeleteFromCloud.append(model)
                                modelContext.delete(model)
                            }
                        }
                        try? modelContext.save()
                        isSelectionMode = false
                        selectedTransactionIDs.removeAll()
                    }
                    Task { for item in itemsToDeleteFromCloud { do { try await FirebaseManager.shared.deleteTransaction(item) } catch { print("Hata") } } }
                }
            } message: {
                Text("Seçtiğiniz \(selectedTransactionIDs.count) adet işlemi kalıcı olarak silmek istediğinize emin misiniz?")
            }
            
            // 🚀 DÜZELTME: T-1 Kurallı gerçek EditTransactionView bağlandı!
            .sheet(item: $transactionToEdit) { item in
                EditTransactionView(transaction: item)
            }
        }
    }
    
    // Boş Durum Tasarımı
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(Color.gray.opacity(0.5))
            Text("Kayıt Bulunamadı")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            Text("Seçili filtreye ait işlem bulunmuyor.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
    }
}

// MODERN LİSTE İÇERİĞİ
struct ModernTransactionRowContent: View {
    let item: TradeTransaction
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.ticker.isEmpty ? "Diğer" : item.ticker)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("\(formatDate(item.date)) • \(itemTypeString)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                let totalValue = item.priceUSD * item.quantity
                
                Text(String(format: "$%.2f", totalValue))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(item.type == .sell ? Color(hex: "1F5EFF") : .primary)
                
                Text(item.type == .dividend || item.type == .other ? "—" : "\(String(format: "%.2f", item.quantity)) Adet")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var iconColor: Color {
        switch item.type {
        case .buy: return .orange
        case .sell: return Color(hex: "1F5EFF")
        case .dividend: return .green
        case .other: return .purple
        }
    }
    
    private var iconName: String {
        switch item.type {
        case .buy: return "arrow.down.left"
        case .sell: return "arrow.up.right"
        case .dividend: return "dollarsign.circle.fill"
        case .other: return "bag.fill"
        }
    }
    
    private var itemTypeString: String {
        switch item.type {
        case .buy: return "Alış"
        case .sell: return "Satış"
        case .dividend: return "Temettü"
        case .other: return "Diğer"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy"
        return f.string(from: date)
    }
}
