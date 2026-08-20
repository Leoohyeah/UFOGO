import Foundation

/// 本地化文本管理器 - 集中管理所有硬編碼的中文文本
enum L10n {
    // MARK: - 搜尋相關
    static let searchPlaceholder = String(localized: "搜尋地點或貼上座標", defaultValue: "搜尋地點或貼上座標")
    static let directLocate = String(localized: "直接定位", defaultValue: "直接定位")
    static let clearSearch = String(localized: "清空搜尋", defaultValue: "清空搜尋")
    static let searchResults = String(localized: "搜尋結果", defaultValue: "搜尋結果")
    
    // MARK: - 書籤相關
    static let copyCoordinate = String(localized: "複製座標", defaultValue: "複製座標")
    static let coordinateCopied = String(localized: "座標已複製", defaultValue: "座標已複製")
    static let bookmark = String(localized: "加入收藏", defaultValue: "加入收藏")
    static let removeBookmark = String(localized: "取消收藏", defaultValue: "取消收藏")
    
    // MARK: - 速度相關
    static let speed = String(localized: "速度控制", defaultValue: "速度控制")
    static let speedUnit = String(localized: "km/hr", defaultValue: "km/hr")
    
    // MARK: - 提示和警告
}
