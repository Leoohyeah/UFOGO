import SwiftUI

/// 統一的搜尋欄元件，支援座標解析和搜尋結果
struct SearchBarWithCoordinateField: View {
    @Binding var searchText: String
    @Binding var showResults: Bool
    @FocusState private var focusedField: Field?
    
    var onSubmit: (String) -> Void = { _ in }
    var onDirectlyLocate: (() -> Void)? = nil
    var maxWidth: CGFloat? = nil
    var isProcessing: Bool = false
    var showDirectLocateButton: Bool = true
    
    private enum Field {
        case search
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            
            TextField(L10n.searchPlaceholder, text: $searchText)
                .focused($focusedField, equals: .search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit {
                    onSubmit(searchText)
                }
                .onChange(of: searchText) { _, value in
                    if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || CoordinateParser.canParse(value) {
                        showResults = false
                    }
                }
            
            if !searchText.isEmpty {
                HStack(spacing: 0) {
                    // 直接定位按鈕（僅當檢測到座標或設置 showDirectLocateButton 時顯示）
                    if showDirectLocateButton && (CoordinateParser.canParse(searchText) || onDirectlyLocate != nil) {
                        Button(action: {
                            onDirectlyLocate?()
                        }) {
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundStyle(.tint)
                                .frame(width: 44, height: 44, alignment: .trailing)
                                .contentShape(Circle())
                        }
                        .padding(.trailing, -4)
                        .disabled(isProcessing)
                        .accessibilityLabel(L10n.directLocate)
                    }

                    // 清空按鈕
                    Button(action: {
                        searchText = ""
                        showResults = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32, alignment: .trailing)
                            .contentShape(Rectangle())
                    }
                    .frame(width: 44, height: 44, alignment: .trailing)
                    .accessibilityLabel(L10n.clearSearch)
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .if(maxWidth != nil) { view in
            view.frame(maxWidth: maxWidth)
        }
        .panelStyle()
        .contentShape(Rectangle())
        .onTapGesture {
            focusedField = .search
        }
    }
    
}

#Preview {
    @Previewable @State var searchText = ""
    @Previewable @State var showResults = false
    
    return SearchBarWithCoordinateField(
        searchText: $searchText,
        showResults: $showResults,
        onSubmit: { _ in },
        onDirectlyLocate: {}
    )
    .padding()
}
