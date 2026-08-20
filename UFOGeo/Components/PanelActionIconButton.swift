import SwiftUI

/// 面板操作按鈕 - 符合 HIG 規範的最小 44×44 點擊區域
struct PanelActionIconButton: View {
    let systemName: String
    var foregroundStyle: Color = .accentColor
    var accessibilityLabel: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .frame(width: 44, height: 44, alignment: .center)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(foregroundStyle)
        .if(accessibilityLabel != nil) { view in
            view.accessibilityLabel(accessibilityLabel ?? "")
        }
    }
}
