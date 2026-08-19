import Combine
import MapKit

final class LocationSearchCompleter: NSObject, ObservableObject {
    @Published var results: [MKLocalSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()
    /// 防抖計時器：延遲 500ms 後才執行搜尋，減少網路請求
    private var debounceTimer: Timer?
    /// 防抖間隔：500ms 無新輸入後才發送搜尋請求
    private static let debounceInterval: TimeInterval = 0.5

    override init() {
        super.init()
        completer.delegate = self
    }

    func update(query: String) {
        // 取消上一個待執行的搜尋
        debounceTimer?.invalidate()
        
        // 如果查詢為空，立即清空結果
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            DispatchQueue.main.async {
                self.results = []
            }
            return
        }
        
        // 延遲 500ms 後才執行搜尋
        debounceTimer = Timer.scheduledTimer(withTimeInterval: Self.debounceInterval, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.completer.queryFragment = query
            }
        }
    }

    func cancelAndClear() {
        debounceTimer?.invalidate()
        debounceTimer = nil
        completer.queryFragment = ""
        results = []
    }
    
    deinit {
        debounceTimer?.invalidate()
    }
}

extension LocationSearchCompleter: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.results = completer.results
        }
    }
}
