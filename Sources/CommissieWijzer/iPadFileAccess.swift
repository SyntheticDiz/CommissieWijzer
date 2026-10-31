#if os(iOS)
import Foundation
import SwiftUI
import UniformTypeIdentifiers
import UIKit

/// Document-provider bridge used by the existing workspace commands on iPad.
/// Imported work documents are copied into app-owned storage so their access
/// survives the picker session and can be autosaved locally.
@MainActor
enum iPadFileAccess {
    private static var coordinators: [UUID: PickerCoordinator] = [:]
    private static let exportFolderBookmarkKey = "commissiewijzer.ipad.exportFolderBookmark.v1"

    static func setPreferredExportDirectory(_ url: URL?) throws {
        guard let url else {
            UserDefaults.standard.removeObject(forKey: exportFolderBookmarkKey)
            return
        }
        guard url.isFileURL else { throw FilePickerError.invalidExportDirectory }
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw FilePickerError.invalidExportDirectory
        }
        let bookmark = try url.bookmarkData(options: .minimalBookmark,
                                            includingResourceValuesForKeys: nil, relativeTo: nil)
        UserDefaults.standard.set(bookmark, forKey: exportFolderBookmarkKey)
    }

    static func chooseExportDirectory(context: AppPresentationContext? = nil, completion: @escaping (Result<URL?, Error>) -> Void) {
        let coordinator = PickerCoordinator(selectingExportDirectory: completion)
        let id = coordinator.id
        coordinators[id] = coordinator
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
        picker.delegate = coordinator
        guard present(picker, context: context) else {
            coordinators.removeValue(forKey: id)
            completion(.failure(FilePickerError.noForegroundPresenter))
            return
        }
    }

    nonisolated static func localCopy(of url: URL) throws -> URL {
        guard url.isFileURL, url.pathExtension.lowercased() == "spdfwork" else {
            throw FilePickerError.unsupportedFile
        }
        if isManaged(url) { return url }
        return try copyIntoManagedStorage(url, folder: "ImportedWorkdocuments", maximumFileSize: 250_000_000)
    }

    nonisolated private static func copyIntoManagedStorage(_ source: URL, folder: String, maximumFileSize: Int64) throws -> URL {
        let hasAccess = source.startAccessingSecurityScopedResource()
        defer { if hasAccess { source.stopAccessingSecurityScopedResource() } }
        guard let reportedSize = try source.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
            throw FilePickerError.fileSizeUnavailable
        }
        guard Int64(reportedSize) <= maximumFileSize else { throw FilePickerError.tooLarge }
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(folder, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let uniqueDirectory = directory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: uniqueDirectory, withIntermediateDirectories: true)
        let destination = uniqueDirectory.appendingPathComponent(source.lastPathComponent)
        try FileManager.default.copyItem(at: source, to: destination)
        return destination
    }

    nonisolated private static func isManaged(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].standardizedFileURL.path
        return path.hasPrefix(support + "/ImportedWorkdocuments/") || path.hasPrefix(support + "/SavedWorkdocuments/")
    }

    static func open(contentTypes: [UTType], context: AppPresentationContext? = nil, completion: @escaping (Result<URL, Error>) -> Void) {
        let maxSize: Int64 = contentTypes.contains(.pdf) ? 100_000_000 : 250_000_000
        let coordinator = PickerCoordinator(maximumFileSize: maxSize, completion: completion)
        let id = coordinator.id
        coordinators[id] = coordinator
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: true)
        picker.delegate = coordinator
        guard present(picker, context: context) else {
            coordinators.removeValue(forKey: id)
            completion(.failure(FilePickerError.noForegroundPresenter))
            return
        }
    }

    static func export(data: Data, filename: String, contentType: UTType,
                       context: AppPresentationContext? = nil,
                       completion: @escaping (Result<URL?, Error>) -> Void) {
        do {
            let suffix = contentType.preferredFilenameExtension ?? URL(fileURLWithPath: filename).pathExtension
            let stagingDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
            let baseName = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
            let staging = stagingDirectory.appendingPathComponent(baseName).appendingPathExtension(suffix)
            try data.write(to: staging, options: .atomic)
            let hadConfiguredExportFolder = UserDefaults.standard.data(forKey: exportFolderBookmarkKey) != nil
            let directoryGrant = preferredExportDirectory()
            let coordinator = PickerCoordinator(stagingURL: staging, directoryGrant: directoryGrant, completion: completion)
            let id = coordinator.id
            coordinators[id] = coordinator
            let picker = UIDocumentPickerViewController(forExporting: [staging], asCopy: true)
            picker.delegate = coordinator
            if let directory = directoryGrant?.url { picker.directoryURL = directory }
            guard present(picker, context: context, information: hadConfiguredExportFolder && directoryGrant == nil
                          ? "De ingestelde exportmap is niet beschikbaar. Kies een andere locatie in Bestanden."
                          : nil) else {
                coordinator.abortPresentation()
                completion(.failure(FilePickerError.noForegroundPresenter))
                return
            }
        } catch { completion(.failure(error)) }
    }

    private static func preferredExportDirectory() -> DirectoryGrant? {
        guard let bookmark = UserDefaults.standard.data(forKey: exportFolderBookmarkKey) else { return nil }
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil,
                                 bookmarkDataIsStale: &isStale), url.isFileURL else {
            UserDefaults.standard.removeObject(forKey: exportFolderBookmarkKey)
            return nil
        }
        let hasAccess = url.startAccessingSecurityScopedResource()
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            if hasAccess { url.stopAccessingSecurityScopedResource() }
            UserDefaults.standard.removeObject(forKey: exportFolderBookmarkKey)
            return nil
        }
        if isStale { try? setPreferredExportDirectory(url) }
        return DirectoryGrant(url: url, hasAccess: hasAccess)
    }

    private struct DirectoryGrant {
        let url: URL
        let hasAccess: Bool
    }

    private static func present(_ picker: UIDocumentPickerViewController, context: AppPresentationContext? = nil, information: String? = nil) -> Bool {
        let presenter: UIViewController?
        if let context {
            // A supplied scene is authoritative. Never redirect a failed presentation
            // to another foreground window.
            presenter = context.foregroundPresenter
        } else {
            let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })
            if let window = scene?.windows.first(where: \.isKeyWindow), var top = window.rootViewController {
                while let presented = top.presentedViewController { top = presented }
                presenter = top.viewIfLoaded?.window === window ? top : nil
            } else { presenter = nil }
        }
        guard let presenter else { return false }
        if let information {
            let alert = UIAlertController(title: "Exportmap niet beschikbaar", message: information, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Kies andere locatie", style: .default) { _ in
                alert.dismiss(animated: true) {
                    guard iPadFileAccess.present(picker, context: context) else {
                        picker.delegate?.documentPickerWasCancelled?(picker)
                        return
                    }
                }
            })
            alert.addAction(UIAlertAction(title: "Annuleer", style: .cancel) { _ in
                picker.delegate?.documentPickerWasCancelled?(picker)
            })
            presenter.present(alert, animated: true)
        } else {
            presenter.present(picker, animated: true)
        }
        return true
    }

    @MainActor
    private final class PickerCoordinator: NSObject, UIDocumentPickerDelegate {
        let id = UUID()
        private var completed = false
        private let stagingURL: URL?
        private let maximumFileSize: Int64
        private let completion: (Result<URL, Error>) -> Void
        private let exportCompletion: ((Result<URL?, Error>) -> Void)?
        private let directoryGrant: DirectoryGrant?
        private let directoryCompletion: ((Result<URL?, Error>) -> Void)?

        init(maximumFileSize: Int64, completion: @escaping (Result<URL, Error>) -> Void) {
            stagingURL = nil; self.maximumFileSize = maximumFileSize
            self.completion = completion; exportCompletion = nil
            directoryGrant = nil; directoryCompletion = nil
        }

        init(stagingURL: URL, directoryGrant: DirectoryGrant?, completion: @escaping (Result<URL?, Error>) -> Void) {
            self.stagingURL = stagingURL; maximumFileSize = .max
            self.completion = { _ in }; exportCompletion = completion
            self.directoryGrant = directoryGrant; directoryCompletion = nil
        }

        init(selectingExportDirectory completion: @escaping (Result<URL?, Error>) -> Void) {
            stagingURL = nil; maximumFileSize = .max
            self.completion = { _ in }; exportCompletion = nil
            directoryGrant = nil; directoryCompletion = completion
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard beginCompletion() else { return }
            guard let picked = urls.first else {
                if let directoryCompletion {
                    directoryCompletion(.failure(CancellationError()))
                    cleanup()
                    return
                }
                if let stagingURL {
                    exportCompletion?(.failure(CancellationError()))
                    cleanup()
                } else {
                    completion(.failure(CancellationError()))
                    cleanup()
                }
                return
            }
            if let directoryCompletion {
                do {
                    try iPadFileAccess.setPreferredExportDirectory(picked)
                    directoryCompletion(.success(picked))
                } catch { directoryCompletion(.failure(error)) }
                cleanup()
                return
            }
            if let stagingURL {
                let resultURL: URL
                if stagingURL.pathExtension.lowercased() == "spdfwork" {
                    do {
                        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                            .appendingPathComponent("SavedWorkdocuments", isDirectory: true)
                        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                        let uniqueDirectory = directory.appendingPathComponent(UUID().uuidString, isDirectory: true)
                        try FileManager.default.createDirectory(at: uniqueDirectory, withIntermediateDirectories: true)
                        resultURL = uniqueDirectory.appendingPathComponent(stagingURL.lastPathComponent)
                        try FileManager.default.copyItem(at: stagingURL, to: resultURL)
                    } catch {
                        exportCompletion?(.failure(error))
                        cleanup()
                        return
                    }
                } else { resultURL = picked }
                exportCompletion?(.success(resultURL))
                cleanup()
            } else {
                do {
                    let folder = picked.pathExtension.lowercased() == "spdfwork" ? "ImportedWorkdocuments" : "ImportedFiles"
                    let destination = try iPadFileAccess.copyIntoManagedStorage(picked, folder: folder,
                                                                                 maximumFileSize: maximumFileSize)
                    finish(.success(destination))
                } catch { finish(.failure(error)) }
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            guard beginCompletion() else { return }
            if let directoryCompletion {
                directoryCompletion(.failure(CancellationError()))
                cleanup()
                return
            }
            if let stagingURL {
                exportCompletion?(.failure(CancellationError()))
                cleanup()
            }
            else {
                completion(.failure(CancellationError()))
                cleanup()
            }
        }

        private func beginCompletion() -> Bool {
            guard !completed else { return false }
            completed = true
            return true
        }

        func abortPresentation() {
            guard beginCompletion() else { return }
            cleanup()
        }

        private func finish(_ result: Result<URL, Error>) {
            completion(result)
            cleanup()
        }

        private func cleanup() {
            if let stagingURL { try? FileManager.default.removeItem(at: stagingURL.deletingLastPathComponent()) }
            if let directoryGrant, directoryGrant.hasAccess { directoryGrant.url.stopAccessingSecurityScopedResource() }
            iPadFileAccess.coordinators.removeValue(forKey: id)
        }
    }

    private enum FilePickerError: LocalizedError {
        case noForegroundPresenter, tooLarge, fileSizeUnavailable, unsupportedFile, invalidExportDirectory
        var errorDescription: String? {
            switch self {
            case .noForegroundPresenter: "De bestandskiezer kan nu niet worden geopend. Keer terug naar CommissieWijzer en probeer opnieuw."
            case .tooLarge: "Dit bestand is te groot om te openen in CommissieWijzer."
            case .fileSizeUnavailable: "De bestandsgrootte kon niet worden gecontroleerd. Download het bestand naar Bestanden en probeer opnieuw."
            case .unsupportedFile: "Kies een bestaand CommissieWijzer-werkdocument (.spdfwork)."
            case .invalidExportDirectory: "Kies een beschikbare map in Bestanden als exportlocatie."
            }
        }
    }
}
#endif
