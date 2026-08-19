import SwiftUI

/// 動畫偏好設定 - 統一應用程序的動畫風格
enum AnimationPreferences {
    /// 標準動畫（0.2 秒）- 用於一般 UI 轉換
    static let standard = Animation.easeInOut(duration: 0.2)
    
    /// 慢速動畫（0.3 秒）- 用於重要狀態變化
    static let slow = Animation.easeInOut(duration: 0.3)
    
    /// 上升轉換 - 用於面板展開
    static let expandTransition = AnyTransition.asymmetric(
        insertion: .move(edge: .top).combined(with: .opacity),
        removal: .move(edge: .top).combined(with: .opacity)
    )
}
