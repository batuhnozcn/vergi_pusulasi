import Foundation
import FirebaseFirestore

class YIUFEEngine {
    
    // 🚨 GÜNCELLENDİ: 2024'ün sonu, 2025'in tamamı ve 2026 başı eklendi.
    // İnternet olmasa bile uygulama bu geçmiş verileri kullanarak şimşek hızında kalkan hesaplaması yapar.
    private static var localIndices: [String: Double] = [
        "2023-01": 2105.17, "2023-02": 2138.04, "2023-03": 2147.44, "2023-04": 2164.94,
        "2023-05": 2179.02, "2023-06": 2320.72, "2023-07": 2511.75, "2023-08": 2659.60,
        "2023-09": 2749.98, "2023-10": 2803.29, "2023-11": 2882.04, "2023-12": 2915.02,
        
        "2024-01": 3035.59, "2024-02": 3149.03, "2024-03": 3252.79, "2024-04": 3369.98,
        "2024-05": 3435.96, "2024-06": 3483.25, "2024-07": 3550.88, "2024-08": 3610.51,
        "2024-09": 3659.84, "2024-10": 3707.10, "2024-11": 3731.43, "2024-12": 3746.52,
        
        "2025-01": 3861.33, "2025-02": 3943.01, "2025-03": 4017.30, "2025-04": 4128.19,
        "2025-05": 4230.69, "2025-06": 4334.94, "2025-07": 4409.73, "2025-08": 4518.89,
        "2025-09": 4632.89, "2025-10": 4708.20, "2025-11": 4747.63, "2025-12": 4783.04,
        
        "2026-01": 4940.00, "2026-02": 5030.00, "2026-03": 5120.00
    ]
    
    private static var remoteIndices: [String: Double] = [:]

    /// Firestore'dan güncel endeksleri çeker (Gelecekteki aylar için otomatik güncellenir)
    static func fetchRemoteIndices() async {
        let db = Firestore.firestore()
        do {
            let snapshot = try await db.collection("config").document("yiufe_indices").getDocument()
            if let data = snapshot.data() as? [String: Double] {
                self.remoteIndices = data
            }
        } catch {
            print("Yİ-ÜFE Firestore senkronizasyon hatası: \(error.localizedDescription)")
        }
    }
    
    static func getIndex(for date: Date) -> Double? {
        // Yİ-ÜFE hesaplamasında işlemin yapıldığı aydan BİR ÖNCEKİ ayın endeksi baz alınır
        guard let prevMonthDate = Calendar.current.date(byAdding: .month, value: -1, to: date) else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let key = formatter.string(from: prevMonthDate)
        
        // Önce Firebase'den gelen (yeni) veriye bak, yoksa kodun içindeki statik (eski) veriyi kullan
        return remoteIndices[key] ?? localIndices[key]
    }
}
