import SwiftUI

/// 主要操作按鈕 - 用於啟動/停止定位
struct PrimaryActionButton: View {
    let isSimulating: Bool
    let isProcessing: Bool
    let isDisabled: Bool
    let action: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            Button(action: action) {
                HStack {
                    if isProcessing {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: isSimulating ? "stop.fill" : "location.fill")
                    }
                    Text(isProcessing ? "處理中…" : (isSimulating ? "停止定位" : "啟動定位"))
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .foregroundStyle(.white)
                .background(
                    isSimulating ? Color(.systemRed) : Color.accentColor,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .disabled(isDisabled || isProcessing)
            .opacity(isDisabled || isProcessing ? 0.55 : 1)
            .frame(width: geometry.size.width * 0.5)
            .frame(maxWidth: .infinity)
        }
        .frame(height: 40)
    }
}
