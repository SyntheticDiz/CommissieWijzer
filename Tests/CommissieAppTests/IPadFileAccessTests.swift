#if os(iOS)
import XCTest
import UniformTypeIdentifiers
import UIKit
@testable import CommissieWijzer

@MainActor
final class IPadFileAccessTests: XCTestCase {
    func testUnattachedContextRejectsEveryPickerAndExportRemovesStagingFile() {
        let context = AppPresentationContext()
        let temporaryName = UUID().uuidString + ".txt"

        var openCount = 0
        var openResult: Result<URL, Error>?
        iPadFileAccess.open(contentTypes: [.data], context: context) {
            openCount += 1
            openResult = $0
        }
        XCTAssertEqual(openCount, 1)
        XCTAssertNotNil(openResult?.failureValue)

        var folderCount = 0
        var folderResult: Result<URL?, Error>?
        iPadFileAccess.chooseExportDirectory(context: context) {
            folderCount += 1
            folderResult = $0
        }
        XCTAssertEqual(folderCount, 1)
        XCTAssertNotNil(folderResult?.failureValue)

        var exportCount = 0
        var exportResult: Result<URL?, Error>?
        iPadFileAccess.export(data: Data("staged contents".utf8), filename: temporaryName,
                              contentType: .plainText, context: context) {
            exportCount += 1
            exportResult = $0
        }
        XCTAssertEqual(exportCount, 1)
        XCTAssertNotNil(exportResult?.failureValue)
        XCTAssertTrue(temporaryFiles(named: temporaryName).isEmpty,
                      "A failed presentation must remove its temporary export file")
    }

    func testAttachedContextPresentsInItsWindowAndCopiesPickedWorkDocument() async throws {
        let host = try await makePresentationHost()
        defer { host.context.attach(nil) }
        let fixture = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "mac-v1", withExtension: "spdfwork"))
        let original = try Data(contentsOf: fixture)
        var callbackCount = 0
        var result: Result<URL, Error>?

        iPadFileAccess.open(contentTypes: [.data], context: host.context) {
            callbackCount += 1
            result = $0
        }

        let picker = try await waitForPicker(from: host.root)
        XCTAssertTrue(host.context.foregroundPresenter?.viewIfLoaded?.window === host.window,
                      "The supplied presentation context must resolve its owning window")
        XCTAssertTrue(picker.presentingViewController?.viewIfLoaded?.window === host.window,
                      "The picker must be presented by the context's window")
        guard let delegate = picker.delegate else { return XCTFail("The bridge must retain a document picker delegate") }
        delegate.documentPicker?(picker, didPickDocumentsAt: [fixture])

        let copiedURL = try XCTUnwrap(result?.get())
        defer { try? FileManager.default.removeItem(at: copiedURL.deletingLastPathComponent()) }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ImportedWorkdocuments", isDirectory: true).standardizedFileURL.path + "/"
        XCTAssertTrue(copiedURL.standardizedFileURL.path.hasPrefix(support))
        XCTAssertEqual(try Data(contentsOf: copiedURL), original)
        XCTAssertEqual(callbackCount, 1)
        picker.dismiss(animated: false)
    }

    func testPickerCancellationCompletesOnceAndExportCancellationCleansStaging() async throws {
        let host = try await makePresentationHost()
        defer { host.context.attach(nil) }

        var openCount = 0
        var openResult: Result<URL, Error>?
        iPadFileAccess.open(contentTypes: [.data], context: host.context) {
            openCount += 1
            openResult = $0
        }
        let openPicker = try await waitForPicker(from: host.root)
        guard let openDelegate = openPicker.delegate else { return XCTFail("The bridge must retain a document picker delegate") }
        openDelegate.documentPickerWasCancelled?(openPicker)
        XCTAssertEqual(openCount, 1)
        guard case .failure(let openError)? = openResult else { return XCTFail("Cancellation should fail the open request") }
        XCTAssertTrue(openError is CancellationError)
        openDelegate.documentPickerWasCancelled?(openPicker)
        XCTAssertEqual(openCount, 1, "A terminal delegate callback must not complete twice")
        openPicker.dismiss(animated: false)
        try await waitForDismissal(of: openPicker, from: host.root)
        let filename = UUID().uuidString + ".txt"
        var exportCount = 0
        var exportResult: Result<URL?, Error>?
        iPadFileAccess.export(data: Data("temporary export".utf8), filename: filename,
                              contentType: .plainText, context: host.context) {
            exportCount += 1
            exportResult = $0
        }
        let exportPicker = try await waitForPicker(from: host.root)
        XCTAssertEqual(temporaryFiles(named: filename).count, 1)
        exportPicker.delegate?.documentPickerWasCancelled?(exportPicker)
        XCTAssertEqual(exportCount, 1)
        guard case .failure(let exportError)? = exportResult else { return XCTFail("Cancellation should fail the export") }
        XCTAssertTrue(exportError is CancellationError)
        XCTAssertTrue(temporaryFiles(named: filename).isEmpty, "Cancelling an export must remove its staging directory")
        exportPicker.dismiss(animated: false)
    }

    func testEmptyExportSelectionReleasesPickerStagingAndCompletesAsCancellation() async throws {
        let host = try await makePresentationHost()
        let bookmarkKey = "commissiewijzer.ipad.exportFolderBookmark.v1"
        let previousBookmark = UserDefaults.standard.data(forKey: bookmarkKey)
        defer {
            host.context.attach(nil)
            if let previousBookmark { UserDefaults.standard.set(previousBookmark, forKey: bookmarkKey) }
            else { UserDefaults.standard.removeObject(forKey: bookmarkKey) }
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try iPadFileAccess.setPreferredExportDirectory(directory)

        let filename = UUID().uuidString + ".spdfwork"
        var result: Result<URL?, Error>?
        iPadFileAccess.export(data: Data("fake work archive".utf8), filename: filename,
                              contentType: UTType(filenameExtension: "spdfwork") ?? .data,
                              context: host.context) { result = $0 }
        let picker = try await waitForPicker(from: host.root)
        XCTAssertEqual(temporaryFiles(named: filename).count, 1)
        guard let delegate = picker.delegate else { return XCTFail("The bridge must retain a document picker delegate") }
        delegate.documentPicker?(picker, didPickDocumentsAt: [])
        guard case .failure(let error)? = result else { return XCTFail("An empty export selection must finish as cancellation") }
        XCTAssertTrue(error is CancellationError)
        XCTAssertTrue(temporaryFiles(named: filename).isEmpty)
        picker.dismiss(animated: false)
    }

    func testLocalCopyRejectsUnsupportedAndOversizedFiles() throws {
        let sourceFolder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: sourceFolder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: sourceFolder) }

        let unsupported = sourceFolder.appendingPathComponent("source.pdf")
        try Data("not a work document".utf8).write(to: unsupported)
        XCTAssertThrowsError(try iPadFileAccess.localCopy(of: unsupported))

        let oversized = sourceFolder.appendingPathComponent("oversized.spdfwork")
        FileManager.default.createFile(atPath: oversized.path, contents: Data())
        let handle = try FileHandle(forWritingTo: oversized)
        try handle.truncate(atOffset: 250_000_001)
        try handle.close()
        XCTAssertThrowsError(try iPadFileAccess.localCopy(of: oversized))
    }

    private func makePresentationHost() async throws -> (window: UIWindow, root: UIViewController, context: AppPresentationContext) {
        var stableSamples = 0
        var scene: UIWindowScene?
        var window: UIWindow?
        var root: UIViewController?
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(15))
        while clock.now < deadline {
            let activeScene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                .first(where: { $0.activationState == .foregroundActive })
            let keyWindow = activeScene?.windows.first(where: \.isKeyWindow)
            let rootController = keyWindow?.rootViewController
            if let activeScene, let keyWindow, let rootController,
               UIApplication.shared.applicationState == .active,
               !keyWindow.isHidden, rootController.viewIfLoaded?.window === keyWindow,
               rootController.presentedViewController == nil,
               !rootController.isBeingPresented, !rootController.isBeingDismissed,
               rootController.transitionCoordinator == nil {
                stableSamples = window === keyWindow && root === rootController ? stableSamples + 1 : 1
                scene = activeScene; window = keyWindow; root = rootController
                if stableSamples >= 5 { break }
            } else {
                stableSamples = 0
            }
            try await Task.sleep(for: .milliseconds(50))
        }
        guard stableSamples >= 5, let scene, let window, let root else {
            throw NSError(domain: "IPadFileAccessTests", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "The app window did not remain foreground active and settled"])
        }
        let context = AppPresentationContext()
        context.attach(window)
        guard context.foregroundWindow === window, context.foregroundPresenter === root else {
            context.attach(nil)
            throw NSError(domain: "IPadFileAccessTests", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "The attached app window did not resolve its presenter"])
        }
        XCTAssertTrue(window.windowScene === scene)
        // Test callbacks are invoked manually, so UIKit will not perform the
        // normal user-driven dismissal. Always clean up, including on failure.
        addTeardownBlock {
            await MainActor.run {
                if let picker = root.presentedViewController as? UIDocumentPickerViewController {
                    picker.delegate?.documentPickerWasCancelled?(picker)
                }
                root.dismiss(animated: false)
                context.attach(nil)
            }
        }
        return (window, root, context)
    }

    private func waitForPicker(from presenter: UIViewController) async throws -> UIDocumentPickerViewController {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(15))
        while clock.now < deadline {
            if let picker = presenter.presentedViewController as? UIDocumentPickerViewController,
               !picker.isBeingPresented, picker.viewIfLoaded?.window != nil { return picker }
            try await Task.sleep(for: .milliseconds(50))
        }
        throw NSError(domain: "IPadFileAccessTests", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "The document picker was not presented"])
    }

    private func waitForDismissal(of picker: UIViewController, from presenter: UIViewController) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(15))
        while clock.now < deadline {
            if presenter.presentedViewController !== picker, presenter.transitionCoordinator == nil { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTFail("The document picker did not finish dismissal")
    }

    private func temporaryFiles(named name: String) -> [URL] {
        let root = FileManager.default.temporaryDirectory
        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil,
                                                        options: [.skipsHiddenFiles])
        return (enumerator?.allObjects as? [URL] ?? []).filter { $0.lastPathComponent == name }
    }
}

private extension Result {
    var failureValue: Failure? {
        guard case .failure(let error) = self else { return nil }
        return error
    }
}
#endif
