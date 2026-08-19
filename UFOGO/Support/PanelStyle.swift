import SwiftUI

/// 通用面板樣式修飾符
struct PanelStyle: ViewModifier {
    var cornerRadius: CGFloat = 14
    var material: Material = .regularMaterial
    
    func body(content: Content) -> some View {
        content
            .background(material, in: RoundedRectangle(cornerRadius: cornerRadius))
    }
}

extension View {
    /// 應用面板樣式
    /// - Parameters:
    ///   - cornerRadius: 圓角半徑，默認 14
    ///   - material: 背景材質，默認 .regularMaterial
    /// - Returns: 應用面板樣式的視圖
    func panelStyle(cornerRadius: CGFloat = 14, material: Material = .regularMaterial) -> some View {
        modifier(PanelStyle(cornerRadius: cornerRadius, material: material))
    }
}
