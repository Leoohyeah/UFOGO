import SwiftUI

/// 通用列表項元件 - 支援標題、副標題和自訂操作
struct ListItemView: View {
    let title: String
    let subtitle: String?
    let onTap: () -> Void
    
    init(
        title: String,
        subtitle: String? = nil,
        onTap: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.onTap = onTap
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .if(subtitle != nil && !subtitle!.isEmpty) { view in
            view.accessibilityValue(subtitle!)
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        ListItemView(
            title: "示例標題",
            subtitle: "示例副標題",
            onTap: {}
        )
        
        Divider()
        
        ListItemView(
            title: "另一個標題",
            onTap: {}
        )
    }
    .panelStyle()
    .padding()
}
