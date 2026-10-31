import XCTest
@testable import CommissieWijzer

final class SavedWorkQueueTests: XCTestCase {
    func testEncodingRunsOffCallerThread() async throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let probe = ThreadProbe()

        SavedWork.schedule(ThreadCheckingSnapshot(probe: probe), key: "thread", directory: folder)
        _ = await SavedWork.drain()

        XCTAssertTrue(probe.wasEncodedOffMainThread)
        XCTAssertEqual(try String(contentsOf: folder.appendingPathComponent("thread.json"), encoding: .utf8), "\"saved\"")
    }

    func testRapidSameKeySavesKeepLatestEnqueuedSnapshot() async throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        SavedWork.schedule("first", key: "same", directory: folder)
        SavedWork.schedule("second", key: "same", directory: folder)
        SavedWork.schedule("latest", key: "same", directory: folder)
        _ = await SavedWork.drain()

        XCTAssertEqual(SavedWork.read(String.self, key: "same", directory: folder), "latest")
    }

    func testSameKeyPendingSnapshotsCoalesceBehindInFlightWrite() async throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let gate = EncodingGate()
        let counter = EncodingCounter()

        SavedWork.schedule(BlockingSnapshot(gate: gate), key: "same", directory: folder)
        XCTAssertEqual(gate.started.wait(timeout: .now() + 2), .success)
        SavedWork.schedule(CountingSnapshot(value: "superseded", counter: counter), key: "same", directory: folder)
        SavedWork.schedule(CountingSnapshot(value: "latest", counter: counter), key: "same", directory: folder)
        gate.release.signal()

        let failures = await SavedWork.drain()
        XCTAssertTrue(failures.isEmpty)
        XCTAssertEqual(counter.count, 1, "Only the newest not-yet-started snapshot should be encoded")
        XCTAssertEqual(SavedWork.read(String.self, key: "same", directory: folder), "latest")
    }

    func testIdenticalKeysInDifferentDirectoriesStayIsolated() async {
        let firstFolder = temporaryFolder()
        let secondFolder = temporaryFolder()
        defer {
            try? FileManager.default.removeItem(at: firstFolder)
            try? FileManager.default.removeItem(at: secondFolder)
        }

        SavedWork.schedule("first document", key: "shared-key", directory: firstFolder)
        SavedWork.schedule("second document", key: "shared-key", directory: secondFolder)
        _ = await SavedWork.drain()

        XCTAssertEqual(SavedWork.read(String.self, key: "shared-key", directory: firstFolder), "first document")
        XCTAssertEqual(SavedWork.read(String.self, key: "shared-key", directory: secondFolder), "second document")
    }

    func testReadAfterScheduledSaveWaitsForThatSave() async {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        SavedWork.schedule("written before read", key: "ordered", directory: folder)
        XCTAssertEqual(SavedWork.read(String.self, key: "ordered", directory: folder), "written before read")
    }

    func testDrainSuspendsUntilQueuedSaveFinishes() async throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let gate = EncodingGate()

        SavedWork.schedule(BlockingSnapshot(gate: gate), key: "blocked", directory: folder)
        XCTAssertEqual(gate.started.wait(timeout: .now() + 2), .success)

        Task {
            _ = await SavedWork.drain()
            gate.drainCompleted.signal()
        }
        XCTAssertEqual(gate.drainCompleted.wait(timeout: .now() + 0.05), .timedOut)
        XCTAssertNil(try? Data(contentsOf: folder.appendingPathComponent("blocked.json")))

        gate.release.signal()
        XCTAssertEqual(gate.drainCompleted.wait(timeout: .now() + 2), .success)
        XCTAssertEqual(SavedWork.read(String.self, key: "blocked", directory: folder), "released")
    }

    func testEncodingFailureNotifiesAndLeavesPreviousFileUntouched() async throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try SavedWork.write(JSONEncoder().encode("previous"), key: "preserved", directory: folder)
        let notified = expectation(forNotification: SavedWork.failure, object: nil)

        SavedWork.schedule(FailingSnapshot(), key: "preserved", directory: folder)
        // The queue barrier proves the write attempt (and its synchronous
        // notification post) has finished before we inspect the expectation.
        let failures = await SavedWork.drain()
        await fulfillment(of: [notified], timeout: 2)

        XCTAssertEqual(failures.count, 1)
        XCTAssertEqual(SavedWork.read(String.self, key: "preserved", directory: folder), "previous")
    }

    func testWriteFailureNotifiesAndLeavesExistingPathUntouched() async throws {
        let root = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: root) }
        let blockedDirectory = root.appendingPathComponent("occupied-by-file")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("keep this file".utf8).write(to: blockedDirectory)
        let notified = expectation(forNotification: SavedWork.failure, object: nil)

        SavedWork.schedule("new value", key: "child", directory: blockedDirectory)
        // Drain before waiting on the observer: otherwise queue scheduling
        // latency can consume the entire XCTest timeout before the write runs.
        let failures = await SavedWork.drain()
        await fulfillment(of: [notified], timeout: 2)

        XCTAssertEqual(failures.count, 1)
        XCTAssertEqual(try Data(contentsOf: blockedDirectory), Data("keep this file".utf8))
    }

    private func temporaryFolder() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("SavedWork-" + UUID().uuidString, isDirectory: true)
    }
}

private final class ThreadProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var encodedOffMain = false

    var wasEncodedOffMainThread: Bool {
        lock.lock(); defer { lock.unlock() }
        return encodedOffMain
    }

    func recordEncoding() {
        lock.lock(); encodedOffMain = !Thread.isMainThread; lock.unlock()
    }
}

private struct ThreadCheckingSnapshot: Encodable, Sendable {
    let probe: ThreadProbe

    func encode(to encoder: Encoder) throws {
        probe.recordEncoding()
        var container = encoder.singleValueContainer()
        try container.encode("saved")
    }
}

private struct FailingSnapshot: Encodable, Sendable {
    func encode(to encoder: Encoder) throws {
        throw EncodingFailure.expected
    }

    private enum EncodingFailure: Error { case expected }
}

private final class EncodingGate: @unchecked Sendable {
    let started = DispatchSemaphore(value: 0)
    let release = DispatchSemaphore(value: 0)
    let drainCompleted = DispatchSemaphore(value: 0)
}

private final class EncodingCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var storedCount = 0

    var count: Int {
        lock.lock(); defer { lock.unlock() }
        return storedCount
    }

    func increment() {
        lock.lock(); storedCount += 1; lock.unlock()
    }
}

private struct CountingSnapshot: Encodable, Sendable {
    let value: String
    let counter: EncodingCounter

    func encode(to encoder: Encoder) throws {
        counter.increment()
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

private struct BlockingSnapshot: Encodable, Sendable {
    let gate: EncodingGate

    func encode(to encoder: Encoder) throws {
        gate.started.signal()
        gate.release.wait()
        var container = encoder.singleValueContainer()
        try container.encode("released")
    }
}
