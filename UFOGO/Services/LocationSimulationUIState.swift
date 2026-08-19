import Foundation
import CoreLocation

extension Notification.Name {
    static let locationSimulationDidExpire = Notification.Name(
        "com.ufogo.location-simulation-did-expire"
    )
}

/// 定位模擬 UI 狀態管理
final class LocationSimulationUIState: ObservableObject {
    // MARK: - 模擬控制
    @Published var isSimulating = false
    @Published var isManuallyStopped = false
    @Published var simulationStatus = ""
    @Published var isProcessingSimulation = false

    // MARK: - 警告和提示
    @Published var showAlert = false
    @Published var alertMessage = ""
    @Published var showCompatibilityCheck = false
    @Published var showInitialPairingPrompt = false
    
    // MARK: - 設定和導航
    @Published var returnToSettingsAfterChild = false
    
    // MARK: - 書籤
    @Published var bookmarks: [LocationBookmark] = []
    @Published var showBookmarks = false
    @Published var showSaveBookmark = false
    @Published var newBookmarkName = ""
    @Published var pendingBookmarkOverwrite: LocationBookmark?
    @Published var showBookmarkOverwriteConfirm = false
    
    /// 性能優化：緩存選中的書籤，避免每次渲染都遍歷
    var cachedSelectedBookmark: LocationBookmark?
    
    // MARK: - 路線導入
    @Published var showRouteImporter = false
    
    // MARK: - 配對導入
    @Published var showPairingImporter = false
    @Published var isImportingPairingFile = false
    
    // MARK: - 內部狀態
    @Published var didApplyActualStartCoordinate = false
    @Published var isReturningToCurrentLocation = false
    @Published var requestAlwaysAfterPairingImport = false
    @Published var recenterAfterPairingAuthorization = false
    @Published var didInitializeView = false
    
    // MARK: - 搖桿相關
    @Published var joystickTouchActive = false
    @Published var joystickDirectionLocked = false
    // 以下僅用於內部邏輯判斷，不需要觸發 SwiftUI 重繪
    var joystickCommandInFlight = false
    var pendingJoystickCoordinate: CLLocationCoordinate2D?
    var lastJoystickUpdateAt: Date = .distantPast
    var joystickHoldStartedAt: Date?
    var joystickHoldAngle: Double = 0
    
    // MARK: - 心跳和通訊
    var lastHeartbeatKeepAliveAt: Date = .distantPast
}
