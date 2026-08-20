import SwiftUI

/// 通用視圖條件修飾符
extension View {
    /// 根據條件應用 modifier
    /// - Parameters:
    ///   - condition: 布爾條件
    ///   - transform: 應用的轉換闭包
    /// - Returns: 條件性修改後的視圖
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
