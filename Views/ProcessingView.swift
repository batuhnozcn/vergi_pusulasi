import SwiftUI

struct ProcessingView: View {
    @State private var progress: CGFloat = 0.0 // Animasyon için
    
    // Checkbox durumları (Tasarımda ilk 2'si seçili, 3.sü boştu)
    @State private var item1Selected = true
    @State private var item2Selected = true
    @State private var item3Selected = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color(hex: "F4F6F9").ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    
                    // İlerleme Animasyonu (Yuvarlak Bar)
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                                .frame(width: 80, height: 80)
                            
                            Circle()
                                .trim(from: 0.0, to: progress)
                                .stroke(Color(hex: "1F5EFF"), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                .frame(width: 80, height: 80)
                                .rotationEffect(.degrees(-90))
                                .animation(.easeOut(duration: 1.5).delay(0.2), value: progress)
                            
                            Text("%75")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Color(hex: "1F5EFF"))
                        }
                        
                        VStack(spacing: 8) {
                            Text("Veri İşleniyor")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text("Yüklediğiniz dosya analiz ediliyor, lütfen bekleyiniz. İşlemler aşağıda listelenmektedir.")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                    }
                    .padding(.top, 24)
                    
                    // İşlem Listesi
                    VStack(spacing: 16) {
                        HStack {
                            Text("Tespit Edilen İşlemler")
                                .font(.system(size: 16, weight: .bold))
                            Spacer()
                            Button("Tümünü Seç") {
                                item1Selected = true; item2Selected = true; item3Selected = true
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: "1F5EFF"))
                        }
                        
                        VStack(spacing: 12) {
                            ScannedItemRow(isSelected: $item1Selected, ticker: "AAPL", name: "Apple Inc.", amount: "$150.00", date: "12 Mayıs 2023")
                            ScannedItemRow(isSelected: $item2Selected, ticker: "TSLA", name: "Tesla, Inc.", amount: "$890.50", date: "14 Mayıs 2023")
                            ScannedItemRow(isSelected: $item3Selected, ticker: "TRY/USD", name: "Forex", amount: "₺15,000", date: "15 Mayıs 2023")
                            
                            // Yükleniyor hissi veren boş (skeleton) kutu
                            HStack {
                                RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.15)).frame(width: 20, height: 20)
                                VStack(alignment: .leading, spacing: 6) {
                                    RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.15)).frame(width: 80, height: 12)
                                    RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.15)).frame(width: 120, height: 10)
                                }
                                Spacer()
                                RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.15)).frame(width: 60, height: 12)
                            }
                            .padding(16)
                            .background(Color.white.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [4])))
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer(minLength: 120) // Alt bar için boşluk
                }
            }
            
            // Alt Sabit Çubuk (Bottom Bar)
            VStack(spacing: 16) {
                Divider()
                
                HStack {
                    Text("2 işlem seçildi")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Toplam: $1,040.50")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 24)
                
                Button(action: { /* Ana Ekrana Kaydedip Dönme İşlemi */ }) {
                    HStack {
                        Text("Devam Et")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(hex: "1F5EFF"))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color(hex: "1F5EFF").opacity(0.3), radius: 8, y: 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            }
            .background(Color.white)
        }
        .navigationTitle("İçe Aktarma")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Sayfa açıldığında yuvarlak barı %75'e doldurma efekti
            progress = 0.75
        }
    }
}

// Özel Checkbox Satır Bileşeni
struct ScannedItemRow: View {
    @Binding var isSelected: Bool
    let ticker: String
    let name: String
    let amount: String
    let date: String
    
    var body: some View {
        Button(action: { isSelected.toggle() }) {
            HStack(spacing: 16) {
                // Checkbox
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? Color(hex: "1F5EFF") : Color.gray.opacity(0.3))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(ticker)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                    Text(name)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(amount)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text(date)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.02), radius: 5, y: 2)
            // Seçili değilse hafif soluk görünür
            .opacity(isSelected ? 1.0 : 0.6)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
