import CoreLocation
import SwiftUI

struct CompatibilityCheckView: View {
    var onImportPairing: (() -> Void)?
    var onImportCoordinates: (() -> Void)?
    var onOpenSavedItems: (() -> Void)?
    var savedItemsTitle: String = "收藏位置"

    private enum TunnelStatus: Equatable {
        case testing, reachable
        case failed(String)
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var sharedMapState: SharedLocationMapState
    @AppStorage(UserDefaults.Keys.lastJoystickSpeed) private var simulationSpeed: Double = 10
    @AppStorage(UserDefaults.Keys.routeCompletionMode) private var completionModeRaw: String = PathCompletionMode.stopAtLast.rawValue
    @AppStorage(UserDefaults.Keys.routePlanningMode) private var routePlanningModeRaw: String = RoutePlanningMode.direct.rawValue
    @AppStorage(UserDefaults.Keys.routeOrbitRadiusMeters) private var routeOrbitRadiusMeters: Int = 30
    @State private var showSupportAlert = false
    @State private var simulationSpeedText = "10"
    @State private var simulationSpeedSlider = 10.0
    @State private var isDraggingSimulationSpeed = false
    @State private var pairingExists = false
    @FocusState private var isSimulationSpeedFocused: Bool

    private let supportURL: URL? = URL(string: "https://portaly.cc/leoohyeah/support")

    private var tunnelStatus: TunnelStatus {
        switch sharedMapState.isTunnelReachable {
        case true: return .reachable
        case false: return .failed("請確認 LocalDevVPN 已開啟後再重新測試。")
        case nil: return .testing
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "未知"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "未知"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            List {
                    Section {
                        connectionOverview
                        compactStatusRow("配對文件", value: pairingExists ? "已就緒" : "需要導入",
                                         color: pairingExists ? .green : .orange)
                        compactStatusRow("VPN Tunnel", value: tunnelCompactText, color: tunnelCompactColor)
                        compactStatusRow("定位權限", value: locationAuthorizationText,
                                         color: locationAuthorizationColor)

                        settingsAction("手動匯入配對文件", icon: "doc.badge.plus",
                                       color: pairingExists ? .accentColor : .orange) {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                onImportPairing?()
                            }
                        }

                        if pairingExists, case .failed = tunnelStatus {
                            Button { sharedMapState.testTunnel(force: true) } label: {
                                Label("重新測試 VPN Tunnel", systemImage: "arrow.clockwise")
                            }
                        }
                    } header: {
                        Text("準備狀態")
                    }

                    Section {
                        HStack {
                            Label("模擬速度", systemImage: "speedometer")
                            Spacer()
                            TextField("0", text: $simulationSpeedText)
                                .multilineTextAlignment(.trailing)
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                .foregroundStyle(.tint)
                                .frame(width: 64)
                                .focused($isSimulationSpeedFocused)
                                .numericInputStyle()
                                .onChange(of: simulationSpeedText) { _, value in
                                    guard let speed = Double(value) else { return }
                                    let clampedValue = min(max(speed, 0), 1000)
                                    sharedMapState.simulationSpeed = clampedValue
                                    simulationSpeed = clampedValue
                                }
                            Text("km/hr")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        Slider(
                            value: sharedSimulationSpeedBinding,
                            in: 0...1000,
                            step: 1,
                            onEditingChanged: { editing in
                                isDraggingSimulationSpeed = editing
                                if !editing {
                                    DispatchQueue.main.async {
                                        simulationSpeed = sharedMapState.simulationSpeed
                                    }
                                }
                            }
                        )
                    } header: {
                        Text("速度")
                    } footer: {
                        Text("定位與路線共用此速度設定，範圍為 0–1000 km/hr。")
                    }

                    Section {
                        Picker("到達終點", selection: $completionModeRaw) {
                            ForEach(PathCompletionMode.allCases) { mode in
                                Text(mode.title).tag(mode.rawValue)
                            }
                        }
                        Picker("路徑規劃", selection: $routePlanningModeRaw) {
                            ForEach(RoutePlanningMode.allCases) { mode in
                                Text(mode.title).tag(mode.rawValue)
                            }
                        }
                        if routePlanningModeRaw == RoutePlanningMode.orbitEachWaypoint.rawValue {
                            Stepper(value: orbitRadiusBinding, in: 1...39) {
                                HStack {
                                    Text("半徑")
                                    Spacer()
                                    Text("\(routeOrbitRadiusMeters)m")
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                            }
                        }
                    } header: {
                        Text("循環模式")
                    } footer: {
                        Text("可分別設定到達終點行為與路徑規劃方式。")
                    }

                    Section("資料管理") {
                        settingsAction(savedItemsTitle, icon: "bookmark.fill") {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                onOpenSavedItems?()
                            }
                        }
                        settingsAction("匯入座標路線", icon: "square.and.arrow.down") {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                onImportCoordinates?()
                            }
                        }
                    }

                    Section("技術資訊") {
                        HStack {
                            Label("程式版本", systemImage: "app.badge")
                            Spacer()
                            Text(appVersion).foregroundStyle(.secondary)
                        }
                    }

                    Section {
                        Button {
                            if let supportURL {
                                openURL(supportURL)
                            } else {
                                showSupportAlert = true
                            }
                        } label: {
                            Label("贊助 UFOGO", systemImage: "heart.fill")
                        }
                    } header: {
                        Text("支持 UFOGO")
                    } footer: {
                        Text("如果喜歡UFOGO，歡迎贊助作者。")
                    }
                }
            .alert("贊助 UFOGO", isPresented: $showSupportAlert) {
                Button("確定", role: .cancel) { }
            } message: {
                Text("贊助連結尚未設定。")
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        commitSimulationSpeedInput()
                        dismiss()
                    }
                }
            }
            .onAppear {
                refreshConnectionStatus()
                let speed = min(max(simulationSpeed, 0), 1000)
                sharedMapState.simulationSpeed = speed
                simulationSpeedText = String(Int(speed))
                simulationSpeedSlider = speed
            }
            .onReceive(NotificationCenter.default.publisher(for: .pairingFileDidChange)) { _ in
                refreshConnectionStatus()
            }
            .onChange(of: simulationSpeed) { _, value in
                sharedMapState.simulationSpeed = min(max(value, 0), 1000)
                if !isDraggingSimulationSpeed {
                    simulationSpeedSlider = value
                }
                guard !isSimulationSpeedFocused else { return }
                simulationSpeedText = String(Int(min(max(value, 0), 1000)))
            }
        }
    }

    private var orbitRadiusBinding: Binding<Int> {
        Binding(
            get: { min(max(routeOrbitRadiusMeters, 1), 39) },
            set: { routeOrbitRadiusMeters = min(max($0, 1), 39) }
        )
    }

    private func commitSimulationSpeedInput() {
        let speed = min(max(Double(simulationSpeedText) ?? simulationSpeed, 0), 1000)
        sharedMapState.simulationSpeed = speed
        simulationSpeed = speed
        simulationSpeedText = String(Int(speed))
    }

    private var sharedSimulationSpeedBinding: Binding<Double> {
        Binding(
            get: { sharedMapState.simulationSpeed },
            set: { value in
                let clampedValue = min(max(value, 0), 1000)
                sharedMapState.simulationSpeed = clampedValue
                simulationSpeedSlider = clampedValue
                if !isSimulationSpeedFocused {
                    simulationSpeedText = String(Int(clampedValue))
                }
            }
        )
    }

    private func compactStatusRow(_ title: String, value: String, color: Color) -> some View {
        HStack {
            Text(title)
            Spacer()
            Circle().fill(color).frame(width: 8, height: 8)
            Text(value).foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }

    private var tunnelCompactText: String {
        switch tunnelStatus {
        case .testing: return "測試中"
        case .reachable: return "正常"
        case .failed: return "無法連線"
        }
    }

    private var tunnelCompactColor: Color {
        switch tunnelStatus {
        case .testing: return .yellow
        case .reachable: return .green
        case .failed: return .red
        }
    }

    private var connectionOverview: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(connectionOverviewColor.opacity(0.14))
                    .frame(width: 52, height: 52)
                Image(systemName: connectionOverviewIcon)
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(connectionOverviewColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(connectionOverviewTitle)
                    .font(.headline)
                Text(connectionOverviewDetail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    private var connectionOverviewColor: Color {
        if !pairingExists { return .orange }
        switch tunnelStatus {
        case .reachable: return .green
        case .failed: return .red
        default: return .accentColor
        }
    }

    private func refreshConnectionStatus() {
        #if targetEnvironment(simulator)
        pairingExists = true
        #else
        pairingExists = FileManager.default.fileExists(
            atPath: PairingFileStore.prepareURL().path
        )
        #endif
        sharedMapState.testTunnel()
    }

    private var connectionOverviewIcon: String {
        if !pairingExists { return "doc.badge.ellipsis" }
        switch tunnelStatus {
        case .reachable: return "checkmark.circle.fill"
        case .failed: return "wifi.exclamationmark"
        default: return "iphone.and.arrow.forward"
        }
    }

    private var connectionOverviewTitle: String {
        if !pairingExists { return "需要配對文件" }
        switch tunnelStatus {
        case .reachable: return "連線準備完成"
        case .failed: return "Tunnel 連線失敗"
        case .testing: return "正在檢查連線"
        }
    }

    private var connectionOverviewDetail: String {
        if !pairingExists { return "先導入此 iPhone 的配對文件，才能啟動定位或路線。" }
        switch tunnelStatus {
        case .reachable: return "UFOGO 已可連接本機 VPN Tunnel。"
        case .failed: return "確認已連上 Wi-Fi 並開啟 LocalDevVPN，再重新測試。"
        case .testing: return "正在確認 LocalDevVPN 是否可以連線。"
        }
    }

    private var locationAuthorizationText: String {
        switch CLLocationManager().authorizationStatus {
        case .authorizedAlways: return "永遠允許"
        case .authorizedWhenInUse: return "使用 App 期間"
        case .denied: return "已拒絕"
        case .restricted: return "受限制"
        case .notDetermined: return "尚未詢問"
        @unknown default: return "未知"
        }
    }

    private var locationAuthorizationColor: Color {
        switch CLLocationManager().authorizationStatus {
        case .authorizedAlways: return .green
        case .authorizedWhenInUse: return .orange
        case .denied, .restricted: return .red
        default: return .secondary
        }
    }

    @ViewBuilder
    private func settingsAction(
        _ title: String,
        icon: String,
        color: Color = .accentColor,
        action: (() -> Void)?
    ) -> some View {
        if let action {
            Button {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: action)
            } label: {
                Label(title, systemImage: icon)
                    .foregroundStyle(color)
            }
        }
    }
}

#Preview {
    CompatibilityCheckView()
        .environmentObject(SharedLocationMapState())
}
