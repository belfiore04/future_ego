import SwiftUI

// MARK: - LocationSettingsView
//
// Lets the user manually type their home and work addresses.
// Plain strings only — no map picker, no geocoding (v2).
// Persisted via `@AppStorage`; `UserLocationStore` reads the same keys.

struct LocationSettingsView: View {

    // MARK: - Persistence
    //
    // Keys must match `UserLocationStore.homeAddressKey` / `.workAddressKey`.

    @AppStorage("user_home_address") private var homeAddress: String = ""
    @AppStorage("user_work_address") private var workAddress: String = ""

    // MARK: - Focus

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case home
        case work
    }

    // MARK: - Body

    var body: some View {
        Form {
            Section {
                addressRow(
                    label: "家",
                    placeholder: "例如：北京市朝阳区…",
                    text: $homeAddress,
                    field: .home
                )

                addressRow(
                    label: "公司",
                    placeholder: "例如：上海市浦东新区…",
                    text: $workAddress,
                    field: .work
                )
            } header: {
                Text("常用地点")
            } footer: {
                Text("仅保存为文字，用于日程与提醒中的地点引用。暂不接入地图或定位。")
            }
        }
        .navigationTitle("常用地点")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") {
                    focusedField = nil
                }
            }
        }
    }

    // MARK: - Row Builder

    @ViewBuilder
    private func addressRow(
        label: String,
        placeholder: String,
        text: Binding<String>,
        field: Field
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(label)
                .font(.system(size: 16))
                .foregroundColor(.black)
                .frame(width: 44, alignment: .leading)

            TextField(placeholder, text: text, axis: .vertical)
                .font(.system(size: 16))
                .foregroundColor(.black)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .lineLimit(1...3)
                .focused($focusedField, equals: field)
                .submitLabel(.done)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Preview

#Preview("常用地点") {
    NavigationStack { LocationSettingsView() }
}
