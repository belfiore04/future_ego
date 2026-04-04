import SwiftUI
import PhotosUI

// MARK: - ProfileEditSheet

struct ProfileEditSheet: View {
    @Binding var nickname: String
    @Binding var motto: String
    @Binding var avatarImage: UIImage?
    @Binding var avatarFileName: String
    @Environment(\.dismiss) private var dismiss

    @State private var editNickname = ""
    @State private var editMotto = ""
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var previewImage: UIImage? = nil
    @State private var pendingAvatarFileName: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Avatar Picker
                Section {
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            avatarPreview
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                // MARK: Nickname
                Section("昵称") {
                    TextField("输入昵称", text: $editNickname)
                }

                // MARK: Motto
                Section("座右铭") {
                    TextField("输入座右铭", text: $editMotto)
                }
            }
            .navigationTitle("编辑资料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                editNickname = nickname
                editMotto = motto
                previewImage = avatarImage
            }
            .onChange(of: selectedPhoto) { _, newItem in
                loadPhoto(newItem)
            }
        }
    }

    // MARK: - Avatar Preview

    @ViewBuilder
    private var avatarPreview: some View {
        ZStack(alignment: .bottomTrailing) {
            if let img = previewImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "34C759"), Color(hex: "30D158")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .overlay(
                        Text(String(editNickname.prefix(1)))
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(.white)
                    )
            }

            // Camera badge
            Circle()
                .fill(Color(hex: "34C759"))
                .frame(width: 26, height: 26)
                .overlay(
                    Image(systemName: "camera.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                )
                .offset(x: 2, y: 2)
        }
    }

    // MARK: - Save

    private func save() {
        let trimmedNickname = editNickname.trimmingCharacters(in: .whitespaces)
        let trimmedMotto = editMotto.trimmingCharacters(in: .whitespaces)
        if !trimmedNickname.isEmpty { nickname = trimmedNickname }
        if !trimmedMotto.isEmpty { motto = trimmedMotto }
        if let img = previewImage, img !== avatarImage {
            avatarImage = img
        }
        if let pending = pendingAvatarFileName {
            avatarFileName = pending
        }
        dismiss()
    }

    // MARK: - Load Photo

    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let img = UIImage(data: data) {
                let fileName = "avatar.png"
                let url = FileManager.default
                    .urls(for: .documentDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent(fileName)
                if let pngData = img.pngData() {
                    try? pngData.write(to: url)
                    await MainActor.run {
                        pendingAvatarFileName = fileName
                        previewImage = img
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ProfileEditSheet(
        nickname: .constant("用户"),
        motto: .constant("每天进步一点点"),
        avatarImage: .constant(nil),
        avatarFileName: .constant("")
    )
}
