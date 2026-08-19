import SwiftUI
import UserNotifications

@main
struct UFOGOApp: App {
    @StateObject private var updateCheckManager = UpdateCheckManager()

    init() {
        AppBootstrapper.configure()
        JoystickModeManager.performRouteLaunchCleanup()
        Self.performColdLaunchCleanup()
        setupTerminationHandler()
        requestNotificationPermission()
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    var body: some Scene {
        WindowGroup {
            ZStack(alignment: .top) {
                MainTabView()

                UpdateAvailableView(updateManager: updateCheckManager)
            }
            .onAppear {
                if updateCheckManager.shouldCheckForUpdates() {
                    updateCheckManager.checkForUpdates()
                }
            }
            .environmentObject(updateCheckManager)
        }
    }

    // MARK: - Termination cleanup

    /// 每次程序冷啟動都視為新的工作階段，不恢復前次模擬。
    @MainActor
    private static func performColdLaunchCleanup() {
        let defaults = UserDefaults.standard
        let hadPersistedSimulation = defaults.bool(
            forKey: UserDefaults.Keys.fixedSimulationActive
        ) || defaults.bool(
            forKey: UserDefaults.Keys.routeSimulationActive
        )

        BackgroundSimulationManager.shared.markSimulationInactive()
        BackgroundLocationManager.shared.stopAllActivities()
        guard hadPersistedSimulation else { return }

        LocationSimulationService.shared.clearLocation(
            operation: "冷啟動清除舊模擬"
        ) { _ in }
    }

    private func setupTerminationHandler() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                Self.performTerminationCleanup()
            }
        }
    }

    /// App 被滑掉時同步清除定位與模擬狀態。
    /// 底層 transport.clearLocation() 是同步呼叫，在 iOS 給予的 ~5 秒內可完成。
    @MainActor
    static func performTerminationCleanup() {
        // 清除持久化狀態，確保下次開啟不會誤恢復。
        BackgroundSimulationManager.shared.markSimulationInactive()
        BackgroundLocationManager.shared.stopAllActivities()

        // 同步送出清除定位指令給裝置（best-effort）。
        LocationSimulationService.shared.clearLocationSync()
    }
}
