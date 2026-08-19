import SwiftUI
import CoreLocation

/// 座標相關操作按鈕組合（複製座標 + 書籤）
struct CoordinateActionButtonGroup: View {
    let coordinate: CLLocationCoordinate2D?
    @State private var didCopyCoordinate = false
    
    var isBookmarked: Bool = false
    var onCopyAction: (() -> Void)? = nil
    var onBookmarkAction: (() -> Void)? = nil
    
    var body: some View {
        if coordinate != nil {
            HStack(spacing: 0) {
                // 複製座標按鈕
                PanelActionIconButton(
                    systemName: didCopyCoordinate ? "checkmark" : "doc.on.doc",
                    foregroundStyle: .accentColor,
                    accessibilityLabel: didCopyCoordinate ? L10n.coordinateCopied : L10n.copyCoordinate,
                    action: {
                        handleCopy()
                    }
                )

                // 書籤按鈕
                PanelActionIconButton(
                    systemName: isBookmarked ? "bookmark.fill" : "bookmark",
                    foregroundStyle: isBookmarked ? .accentColor : .secondary,
                    accessibilityLabel: isBookmarked ? L10n.removeBookmark : L10n.bookmark,
                    action: {
                        onBookmarkAction?()
                    }
                )
            }
            .frame(height: 44, alignment: .top)
        }
    }
    
    /// 處理複製操作
    private func handleCopy() {
        guard let coordinate else { return }
        
        // 複製座標到剪貼板
        UIPasteboard.general.string = CoordinateDisplayFormatter.string(coordinate)
        Haptics.selection()
        
        // 顯示複製成功狀態，1.5 秒後恢復
        withAnimation(AnimationPreferences.standard) {
            didCopyCoordinate = true
        }
        
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(AnimationPreferences.standard) {
                didCopyCoordinate = false
            }
        }
        
        // 執行自訂複製回調
        onCopyAction?()
    }
}

#Preview {
    VStack(spacing: 16) {
        CoordinateActionButtonGroup(
            coordinate: CLLocationCoordinate2D(latitude: 25.0, longitude: 121.5),
            isBookmarked: false,
            onCopyAction: {},
            onBookmarkAction: {}
        )
        
        CoordinateActionButtonGroup(
            coordinate: CLLocationCoordinate2D(latitude: 25.0, longitude: 121.5),
            isBookmarked: true,
            onBookmarkAction: {}
        )
        
        CoordinateActionButtonGroup(
            coordinate: nil
        )
        
        Spacer()
    }
    .padding()
}
