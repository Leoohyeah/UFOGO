import Foundation

extension UserDefaults {
    enum Keys {
        static let targetDeviceIP = "TunnelDeviceIP"
        static let primaryTabSelection = "primaryTabSelection"
        static let hasShownInitialPairingPrompt = "hasShownInitialPairingPrompt"
        static let fixedSimulationActive = "fixedSimulationActive"
        static let routeSimulationActive = "routeSimulationActive"
        static let noSimulationBackgroundAt = "noSimulationBackgroundAt"
        static let lastJoystickSpeed = "lastJoystickSpeed"
        static let savedSimulationRoutes = "SavedSimulationRoutes"
        static let locationBookmarks = "locationBookmarks"
        static let locationHistoryRecords = "locationHistoryRecords"
        static let lastUpdateCheckDate = "lastUpdateCheckDate"
        // 路線模擬設定
        static let routeCompletionMode = "routeCompletionMode"
        static let routePlanningMode = "routePlanningMode"
        static let routeOrbitRadiusMeters = "routeOrbitRadiusMeters"
    }
}
