import Foundation
import FirebaseFirestore
import FirebaseAuth

class FirebaseManager {
    static let shared = FirebaseManager()
    private let db = Firestore.firestore()
    
    private var userPath: CollectionReference? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        return db.collection("users").document(uid).collection("transactions")
    }
    
    func saveTransaction(_ tx: TradeTransaction) async throws {
        guard let path = userPath else { throw NSError(domain: "AuthError", code: 401, userInfo: [NSLocalizedDescriptionKey: "Kullanıcı oturumu bulunamadı."]) }
        
        let data: [String: Any] = [
            "id": tx.id.uuidString,
            "ticker": tx.ticker,
            "type": tx.typeRaw,
            "quantity": tx.quantity,
            "priceUSD": tx.priceUSD,
            "commissionUSD": tx.commissionUSD,
            "date": Timestamp(date: tx.date),
            "fxRate": tx.fxRate,
            "updatedAt": Timestamp(date: tx.updatedAt),
            "isDeleted": tx.isDeleted
        ]
        
        try await path.document(tx.id.uuidString).setData(data, merge: true)
    }
    
    // 🚀 YENİ EKLENDİ: Gerçek (Hard) Silme İşlemi. Zombi verilerin kökünü kazır.
    func deleteTransaction(_ tx: TradeTransaction) async throws {
        guard let path = userPath else { throw NSError(domain: "AuthError", code: 401, userInfo: [NSLocalizedDescriptionKey: "Kullanıcı oturumu bulunamadı."]) }
        try await path.document(tx.id.uuidString).delete()
    }
    
    // Mevcut Soft-Delete (İleride geri dönüşüm kutusu yaparsan diye dokunmadım)
    func markAsDeleted(id: UUID) async throws {
        guard let path = userPath else { throw NSError(domain: "AuthError", code: 401, userInfo: [NSLocalizedDescriptionKey: "Kullanıcı oturumu bulunamadı."]) }
        try await path.document(id.uuidString).setData([
            "isDeleted": true,
            "updatedAt": Timestamp(date: Date())
        ], merge: true)
    }
    
    func fetchAllFromCloud() async -> [[String: Any]] {
        guard let path = userPath else { return [] }
        do {
            let snapshot = try await path.getDocuments()
            return snapshot.documents.map { $0.data() }
        } catch {
            return []
        }
    }
    
    func deleteAllUserData() async {
        guard let path = userPath else { return }
        do {
            let snapshot = try await path.getDocuments()
            for doc in snapshot.documents {
                try await doc.reference.delete()
            }
        } catch {
            print("Bulut verilerini silerken hata: \(error)")
        }
    }
}
