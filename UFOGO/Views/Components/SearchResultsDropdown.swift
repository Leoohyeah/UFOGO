import SwiftUI
import MapKit

/// 搜尋結果下拉清單元件
/// 顯示搜尋結果的下拉列表，使用統一的列表項樣式
struct SearchResultsDropdown: View {
    let results: [MKLocalSearchCompletion]
    let isVisible: Bool
    let maxWidth: CGFloat?
    let onSelectResult: (MKLocalSearchCompletion) -> Void
    
    var body: some View {
        if isVisible && !results.isEmpty {
            VStack(spacing: 0) {
                ForEach(results.prefix(5), id: \.self) { result in
                    ListItemView(
                        title: result.title,
                        subtitle: result.subtitle.isEmpty ? nil : result.subtitle,
                        onTap: { onSelectResult(result) }
                    )
                    
                    // 在每項之間添加分隔線（除了最後一項）
                    if result != results.prefix(5).last {
                        Divider()
                    }
                }
            }
            .if(maxWidth != nil) { view in
                view.frame(maxWidth: maxWidth)
            }
            .panelStyle()
            .accessibilityElement(children: .contain)
            .accessibilityLabel(L10n.searchResults)
            .accessibilityValue("共 \(results.count) 項結果")
        }
    }
}

#Preview {
    @Previewable @State var isVisible = true
    
    let mockResults = [
        MKLocalSearchCompletion(),
        MKLocalSearchCompletion(),
    ]
    
    return SearchResultsDropdown(
        results: mockResults,
        isVisible: isVisible,
        maxWidth: 320,
        onSelectResult: { _ in }
    )
    .padding()
}
