import SwiftUI
import SwiftData
import PhotosUI
import FirebaseAuth

struct ProfileEditView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var existingTransactions: [TradeTransaction]
    
    @AppStorage("userSessionActive") private var userSessionActive = true
    @AppStorage("userName") private var userName = ""
    @AppStorage("userEmail") private var userEmail = ""
    @AppStorage("profileImageData") private var profileImageData: Data?
    
    @State private var showingImageActionSheet = false
    @State private var showingCamera = false
    @State private var showingPhotoPicker = false
    @State private var selectedCameraImage: UIImage?
    @State private var photosSelection: PhotosPickerItem?
    
    @State private var showingPasswordResetAlert = false
    @State private var passwordResetMessage = ""
    @State private var showingDeleteConfirmAlert = false
    @State private var showingDeleteErrorAlert = false
    @State private var deleteErrorMessage = ""
    @State private var showingLogoutConfirmAlert = false
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    profileImageSection
                    personalInfoSection
                    passwordSection
                    accountManagementSection
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
            }
        }
        .navigationTitle("Profili Düzenle")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) { Image(systemName: "chevron.left"); Text("Geri") }
                    .font(.system(size: 16, weight: .medium)).foregroundColor(Color(hex: "1F5EFF"))
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Bitti") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    updateFirebaseProfileName()
                    dismiss()
                }.font(.system(size: 16, weight: .bold)).foregroundColor(Color(hex: "1F5EFF"))
            }
        }
        .onAppear {
            if let user = Auth.auth().currentUser {
                if let email = user.email { userEmail = email }
                if let name = user.displayName, !name.isEmpty { userName = name }
            }
        }
        .confirmationDialog("Fotoğraf Seç", isPresented: $showingImageActionSheet) {
            Button("Kamera") { showingCamera = true }
            Button("Galeri") { showingPhotoPicker = true }
            if profileImageData != nil { Button("Mevcut Fotoğrafı Kaldır", role: .destructive) { profileImageData = nil } }
            Button("İptal", role: .cancel) { }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            SystemCameraPicker(selectedImage: $selectedCameraImage).ignoresSafeArea()
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $photosSelection, matching: .images)
        .onChange(of: photosSelection) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self), let uiImage = UIImage(data: data) {
                    if let compressed = uiImage.jpegData(compressionQuality: 0.5) { profileImageData = compressed }
                }
            }
        }
        .onChange(of: selectedCameraImage) { _, newValue in
            if let uiImage = newValue {
                if let compressed = uiImage.jpegData(compressionQuality: 0.5) { profileImageData = compressed }
            }
        }
        .alert("Şifre Sıfırlama", isPresented: $showingPasswordResetAlert) {
            Button("Tamam", role: .cancel) { }
        } message: { Text(passwordResetMessage) }
        
        .alert("Çıkış Yap", isPresented: $showingLogoutConfirmAlert) {
            Button("İptal", role: .cancel) { }
            Button("Çıkış Yap", role: .destructive) { logOutUser() }
        } message: { Text("Oturumunuz kapatılacaktır. Onaylıyor musunuz?") }
        
        .alert("Hesabı Kalıcı Olarak Sil", isPresented: $showingDeleteConfirmAlert) {
            Button("İptal", role: .cancel) { }
            Button("Evet, Sil", role: .destructive) { deleteFirebaseAccount() }
        } message: { Text("Hesabınızı silmek tüm verilerinizi ve erişiminizi kalıcı olarak silecektir. Bu işlemi onaylıyor musunuz?") }
        
        .alert("Hata", isPresented: $showingDeleteErrorAlert) {
            Button("Tamam", role: .cancel) { }
        } message: { Text(deleteErrorMessage) }
    }
    
    // MARK: - Subviews (Derleyiciyi rahatlatmak için bölündü)
    private var profileImageSection: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                if let data = profileImageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage).resizable().scaledToFill().frame(width: 100, height: 100).clipShape(Circle())
                } else {
                    Circle().fill(Color(hex: "FFE4C4")).frame(width: 100, height: 100).overlay(Image(systemName: "person.fill").resizable().scaledToFit().frame(width: 50).foregroundColor(Color.orange.opacity(0.5)).offset(y: 10).clipShape(Circle())).clipShape(Circle())
                }
                Circle().fill(Color(hex: "1F5EFF")).frame(width: 28, height: 28).overlay(Image(systemName: "pencil").font(.system(size: 14, weight: .bold)).foregroundColor(.white)).overlay(Circle().stroke(Color(UIColor.systemGroupedBackground), lineWidth: 3))
            }
            Button("Fotoğrafı Değiştir") { showingImageActionSheet = true }.font(.system(size: 15, weight: .medium)).foregroundColor(Color(hex: "1F5EFF"))
        }.padding(.top, 24)
    }
    
    private var personalInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("KİŞİSEL BİLGİLER").font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary).padding(.horizontal, 8)
            VStack(spacing: 0) {
                HStack { Text("Ad Soyad").font(.system(size: 16)).foregroundColor(.primary); Spacer(); TextField("Adınızı girin", text: $userName).multilineTextAlignment(.trailing).foregroundColor(.secondary) }.padding(.horizontal, 16).padding(.vertical, 16)
                Divider().padding(.leading, 16)
                HStack { Text("E-posta").font(.system(size: 16)).foregroundColor(.primary); Spacer(); Text(userEmail).foregroundColor(.secondary.opacity(0.7)) }.padding(.horizontal, 16).padding(.vertical, 16)
            }.background(Color(UIColor.secondarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private var passwordSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ŞİFRE İŞLEMLERİ").font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary).padding(.horizontal, 8)
            Button(action: { sendPasswordReset() }) { HStack { Text("Şifreyi Güncelle").font(.system(size: 16)).foregroundColor(Color(hex: "1F5EFF")); Spacer(); Image(systemName: "envelope.fill").font(.system(size: 14)).foregroundColor(.secondary.opacity(0.5)) }.padding(.horizontal, 16).padding(.vertical, 16).background(Color(UIColor.secondarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 12)) }
            Text("Güvenliğiniz için şifrenizi düzenli aralıklarla değiştirmeniz önerilir.").font(.system(size: 12)).foregroundColor(.secondary).padding(.horizontal, 8)
        }
    }
    
    private var accountManagementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HESAP YÖNETİMİ").font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary).padding(.horizontal, 8)
            Button(action: { showingLogoutConfirmAlert = true }) { Text("Çıkış Yap").font(.system(size: 16, weight: .medium)).foregroundColor(Color(hex: "1F5EFF")).frame(maxWidth: .infinity).padding(.vertical, 16).background(Color(UIColor.secondarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 12)) }
            Button(action: { showingDeleteConfirmAlert = true }) { Text("Hesabı Sil").font(.system(size: 16, weight: .medium)).foregroundColor(.red).frame(maxWidth: .infinity).padding(.vertical, 16).background(Color(UIColor.secondarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 12)) }
            Text("Hesabınızı silmek kalıcı bir işlemdir ve verileriniz geri getirilemez.").font(.system(size: 12)).foregroundColor(.secondary).padding(.horizontal, 8)
        }
    }
    
    // MARK: - Functions
    private func logOutUser() {
        do { try Auth.auth().signOut(); wipeLocalDataAndSession() }
        catch { print("Çıkış yapılırken hata: \(error)") }
    }
    
    private func deleteFirebaseAccount() {
        Task {
            await FirebaseManager.shared.deleteAllUserData()
            await MainActor.run {
                Auth.auth().currentUser?.delete { error in
                    if error != nil {
                        deleteErrorMessage = "Güvenlik nedeniyle hesabınızı silebilmeniz için uygulamadan çıkış yapıp tekrar giriş yapmanız gerekmektedir."
                        showingDeleteErrorAlert = true
                    } else {
                        wipeLocalDataAndSession()
                    }
                }
            }
        }
    }
    
    private func wipeLocalDataAndSession() {
        for tx in existingTransactions { modelContext.delete(tx) }
        userName = ""; userEmail = ""; profileImageData = nil; userSessionActive = false
    }
    
    private func updateFirebaseProfileName() { guard let user = Auth.auth().currentUser else { return }; let changeRequest = user.createProfileChangeRequest(); changeRequest.displayName = userName; changeRequest.commitChanges { _ in } }
    private func sendPasswordReset() { guard let email = Auth.auth().currentUser?.email else { return }; Auth.auth().sendPasswordReset(withEmail: email) { error in if let error = error { passwordResetMessage = error.localizedDescription } else { passwordResetMessage = "Şifre sıfırlama bağlantısı '\(email)' adresinize gönderildi. Lütfen gelen kutunuzu kontrol edin." }; showingPasswordResetAlert = true } }
}

struct SystemCameraPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    func makeUIViewController(context: Context) -> UIImagePickerController { let picker = UIImagePickerController(); picker.sourceType = .camera; picker.delegate = context.coordinator; return picker }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: SystemCameraPicker
        init(_ parent: SystemCameraPicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) { if let image = info[.originalImage] as? UIImage { parent.selectedImage = image }; parent.presentationMode.wrappedValue.dismiss() }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.presentationMode.wrappedValue.dismiss() }
    }
}
