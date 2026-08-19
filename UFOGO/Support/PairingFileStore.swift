import Foundation
import UniformTypeIdentifiers

extension Notification.Name {
    static let pairingFileDidChange = Notification.Name("com.ufogo.pairing-file-did-change")
}

enum PairingFileError: LocalizedError, Equatable {
    case fileTooLarge
    case invalidPropertyList
    case missingRequiredFields([String])
    case invalidField(String)

    var errorDescription: String? {
        switch self {
        case .fileTooLarge:
            return "配對文件過大，請重新匯出有效的配對文件。"
        case .invalidPropertyList:
            return "配對文件不是有效的 Property List。"
        case .missingRequiredFields(let fields):
            return "配對文件缺少必要欄位：\(fields.joined(separator: "、"))。"
        case .invalidField(let field):
            return "配對文件欄位 \(field) 的格式無效。"
        }
    }
}

enum PairingFileStore {
    static let fileName = "rp_pairing_file.plist"
    private static let maximumFileSize = 10 * 1_024 * 1_024
    private static let requiredStringFields = ["HostID", "SystemBUID"]
    private static let requiredDataFields = [
        "DeviceCertificate",
        "HostCertificate",
        "HostPrivateKey",
        "RootCertificate",
        "RootPrivateKey"
    ]
    private static let provisionedFileNames = [
        fileName,
        "pairingFile.plist",
        "pairing.mobiledevicepairing",
        "pairing.mobiledevicepair"
    ]
    static let supportedContentTypes: [UTType] = [
        UTType(filenameExtension: "mobiledevicepairing", conformingTo: .data)!,
        UTType(filenameExtension: "mobiledevicepair", conformingTo: .data)!,
        .propertyList
    ]

    static var url: URL {
        directoryURL.appendingPathComponent(fileName)
    }

    @discardableResult
    static func prepareURL(fileManager: FileManager = .default) -> URL {
        let destination = url
        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        guard !fileManager.fileExists(atPath: destination.path) else {
            removeLegacyCopies(fileManager: fileManager)
            return destination
        }

        migrateProvisionedCopy(to: destination, fileManager: fileManager)
        return destination
    }

    static func replace(with sourceURL: URL, fileManager: FileManager = .default) throws {
        let destination = url
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let data = try Data(contentsOf: sourceURL, options: .mappedIfSafe)
        try validate(data)

        guard sourceURL.standardizedFileURL != destination.standardizedFileURL else {
            protectPairingFile(at: destination, fileManager: fileManager)
            return
        }

        removeLegacyCopies(fileManager: fileManager)
        try data.write(to: destination, options: .atomic)
        protectPairingFile(at: destination, fileManager: fileManager)
        notifyPairingFileDidChange()
    }

    static func validate(_ data: Data) throws {
        guard data.count <= maximumFileSize else {
            throw PairingFileError.fileTooLarge
        }

        let propertyList: Any
        do {
            propertyList = try PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
            )
        } catch {
            throw PairingFileError.invalidPropertyList
        }

        guard let dictionary = propertyList as? [String: Any] else {
            throw PairingFileError.invalidPropertyList
        }

        let missing = (requiredStringFields + requiredDataFields).filter {
            dictionary[$0] == nil
        }
        guard missing.isEmpty else {
            throw PairingFileError.missingRequiredFields(missing)
        }

        for field in requiredStringFields {
            guard let value = dictionary[field] as? String,
                  !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw PairingFileError.invalidField(field)
            }
        }
        for field in requiredDataFields {
            guard let value = dictionary[field] as? Data, !value.isEmpty else {
                throw PairingFileError.invalidField(field)
            }
        }
    }

    static func importFromPicker(_ sourceURL: URL, fileManager: FileManager = .default) throws {
        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw CocoaError(.fileNoSuchFile)
        }

        try replace(with: sourceURL, fileManager: fileManager)
    }

    static func remove(fileManager: FileManager = .default) throws {
        let destination = prepareURL(fileManager: fileManager)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        removeLegacyCopies(fileManager: fileManager)
        notifyPairingFileDidChange()
    }

    private static var directoryURL: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Pairing", isDirectory: true)
    }

    private static var provisionedURLs: [URL] {
        let documents = URL.documentsDirectory
        let inbox = documents.appendingPathComponent("Inbox", isDirectory: true)
        let containerURLs = provisionedFileNames.flatMap { name in
            [documents.appendingPathComponent(name), inbox.appendingPathComponent(name)]
        }
        let bundledURLs = provisionedFileNames.compactMap { name -> URL? in
            let fileURL = URL(fileURLWithPath: name)
            return Bundle.main.url(
                forResource: fileURL.deletingPathExtension().lastPathComponent,
                withExtension: fileURL.pathExtension
            )
        }
        let extensions = Set(["plist", "mobiledevicepairing", "mobiledevicepair"])
        let searchableDirectories = [documents, inbox, Bundle.main.bundleURL]
        let wildcardURLs = searchableDirectories.flatMap { directory in
            let urls = (try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )) ?? []
            return urls.filter { url in
                extensions.contains(url.pathExtension.lowercased())
                    && (url.lastPathComponent.lowercased().contains("pair")
                        || url.pathExtension.lowercased().hasPrefix("mobiledevicepair"))
            }
        }
        return Array(Set(containerURLs + bundledURLs + wildcardURLs))
    }

    private static func migrateProvisionedCopy(to destination: URL, fileManager: FileManager) {
        for sourceURL in provisionedURLs where fileManager.fileExists(atPath: sourceURL.path) {
            do {
                let data = try Data(contentsOf: sourceURL, options: .mappedIfSafe)
                try validate(data)
                try data.write(to: destination, options: .atomic)
                if !sourceURL.path.hasPrefix(Bundle.main.bundleURL.path) {
                    try fileManager.removeItem(at: sourceURL)
                }
            } catch {
                continue
            }

            protectPairingFile(at: destination, fileManager: fileManager)
            break
        }
    }

    private static func removeLegacyCopies(fileManager: FileManager) {
        for sourceURL in provisionedURLs
        where !sourceURL.path.hasPrefix(Bundle.main.bundleURL.path)
            && fileManager.fileExists(atPath: sourceURL.path) {
            try? fileManager.removeItem(at: sourceURL)
        }
    }

    private static func protectPairingFile(at url: URL, fileManager: FileManager) {
        try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private static func notifyPairingFileDidChange() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .pairingFileDidChange, object: nil)
        }
    }
}
