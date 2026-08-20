import SwiftUI
import CoreLocation

struct CoordinateToRouteView: View {
    private enum FocusField: Hashable {
        case routeName
        case coordinates
    }

    @ObservedObject var modeManager: JoystickModeManager
    var onRouteImported: ((UUID) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    @State private var routeName = ""
    @State private var suggestedRouteName = ""
    @State private var coordinateText = ""
    @State private var parsedCoordinates: [CLLocationCoordinate2D] = []
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var pendingRouteOverwrite: SimulationRoute?
    @State private var showOverwriteConfirm = false
    @State private var showFileImporter = false
    @State private var isImportingFile = false
    @State private var importedFileName: String?
    @FocusState private var focusedField: FocusField?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("貼上座標或選擇路線檔案")
                            .font(.headline)
                        Spacer()
                        Button {
                            focusedField = nil
                            showFileImporter = true
                        } label: {
                            if isImportingFile {
                                ProgressView()
                            } else {
                                Label("選擇檔案", systemImage: "doc.badge.plus")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isImportingFile)
                    }

                    Text("檔案匯入僅支援 GPX；也可直接貼上座標文字")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("路線名稱", text: $routeName)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .routeName)
                        .submitLabel(.done)
                        .onSubmit { focusedField = nil }

                    Text("格式範例")
                        .font(.caption.bold())
                    Text("25.033964, 121.564468\n25.034200, 121.565100")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextEditor(text: $coordinateText)
                        .focused($focusedField, equals: .coordinates)
                        .frame(height: 220)
                        .scrollContentBackground(.hidden)
                        .padding(6)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(.systemGray3).opacity(0.5), lineWidth: 1)
                        )
                        .onChange(of: coordinateText) { _, newValue in
                            if !newValue.isEmpty { importedFileName = nil }
                            parsedCoordinates = CoordinateImportParser.parseInline(newValue)
                        }

                    Text(importStatusText)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        Button("清空") {
                            focusedField = nil
                            coordinateText = ""
                            parsedCoordinates = []
                            importedFileName = nil
                        }
                        .buttonStyle(.bordered)

                        Button("建立路線") {
                            focusedField = nil
                            createRouteFromParsedCoordinates()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(parsedCoordinates.count < 2)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
            .background {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { focusedField = nil }
            }
            .navigationTitle("匯入座標路線")
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: CoordinateImportParser.gpxContentTypes,
                allowsMultipleSelection: false,
                onCompletion: importCoordinateFile
            )
            .onAppear {
                modeManager.reloadRoutes()
                guard routeName.isEmpty else { return }
                let name = RouteNameGenerator.nextAvailableName(in: modeManager.routes)
                suggestedRouteName = name
                routeName = name
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") {
                        focusedField = nil
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") {
                        focusedField = nil
                        KeyboardDismissal.dismiss()
                    }
                }
            }
            .alert("無法建立路線", isPresented: $showAlert) {
                Button("確定", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            .alert("路線名稱重複", isPresented: $showOverwriteConfirm) {
                Button("覆蓋", role: .destructive) { overwritePendingRoute() }
                Button("取消", role: .cancel) { pendingRouteOverwrite = nil }
            } message: {
                Text("已存在相同名稱的路線，是否以目前內容覆蓋？")
            }
        }
    }

    private func createRouteFromParsedCoordinates() {
        guard parsedCoordinates.count >= 2 else {
            alertMessage = "至少需要 2 個有效座標。"
            showAlert = true
            return
        }

        let trimmedName = routeName.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmedName.isEmpty
            ? (suggestedRouteName.isEmpty ? RouteNameGenerator.nextAvailableName(in: modeManager.routes) : suggestedRouteName)
            : trimmedName
        var route = modeManager.createNewRoute(name: finalName)
        for coordinate in parsedCoordinates {
            modeManager.addPathPoint(coordinate, to: &route)
        }
        route.isFavorite = true
        if let existing = routeWithSameName(as: route.name) {
            route.id = existing.id
            route.createdDate = existing.createdDate
            pendingRouteOverwrite = route
            showOverwriteConfirm = true
        } else {
            modeManager.saveRoute(route)
            onRouteImported?(route.id)
            dismiss()
        }
    }

    private var importStatusText: String {
        if let importedFileName {
            return "\(importedFileName) · \(parsedCoordinates.count) 個路點"
        }
        return "已解析 \(parsedCoordinates.count) 個路點"
    }

    private func importCoordinateFile(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            isImportingFile = true
            let fileName = url.lastPathComponent
            Task {
                do {
                    let coordinates = try await Task.detached(priority: .userInitiated) {
                        try CoordinateImportParser.parse(url: url)
                    }.value
                    await MainActor.run {
                        parsedCoordinates = coordinates
                        coordinateText = coordinates
                            .map {
                                String(
                                    format: "%.6f, %.6f",
                                    locale: Locale(identifier: "en_US_POSIX"),
                                    $0.latitude,
                                    $0.longitude
                                )
                            }
                            .joined(separator: "\n")
                        importedFileName = fileName
                        isImportingFile = false
                    }
                } catch {
                    await MainActor.run {
                        alertMessage = error.localizedDescription
                        showAlert = true
                        isImportingFile = false
                    }
                }
            }
        case .failure(let error):
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    private func overwritePendingRoute() {
        guard let route = pendingRouteOverwrite else { return }
        modeManager.saveRoute(route)
        pendingRouteOverwrite = nil
        onRouteImported?(route.id)
        dismiss()
    }

    private func routeWithSameName(as name: String) -> SimulationRoute? {
        modeManager.routes.first { SavedItemNameMatcher.matches($0.name, name) }
    }

}

#Preview {
    CoordinateToRouteView(modeManager: JoystickModeManager())
}
