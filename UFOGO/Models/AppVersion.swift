import Foundation

/// GitHub Release 版本信息模型
struct AppVersion: Codable {
    let tagName: String
    let name: String
    let body: String
    let releaseDate: String
    let downloadUrl: String?

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case releaseDate = "published_at"
        case downloadUrl = "html_url"
    }

    /// 提取版本號（去掉前綴 "v"）
    var versionNumber: String {
        tagName.replacingOccurrences(of: "v", with: "")
    }

    /// 比較版本大小
    /// - Returns: true 如果當前版本大於輸入版本
    func isNewerThan(_ otherVersion: String) -> Bool {
        let currentComponents = versionNumber.split(separator: ".").compactMap { Int($0) }
        let otherComponents = otherVersion.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(currentComponents.count, otherComponents.count) {
            let current = i < currentComponents.count ? currentComponents[i] : 0
            let other = i < otherComponents.count ? otherComponents[i] : 0

            if current > other { return true }
            if current < other { return false }
        }

        return false
    }
}
