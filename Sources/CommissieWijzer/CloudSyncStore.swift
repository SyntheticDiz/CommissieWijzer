import Foundation
import CryptoKit

struct CloudDossier: Identifiable, Codable, Sendable {
    let id: UUID
    var title: String
    var modifiedAt: Date
    var isConflict: Bool
    var hasLocalChanges: Bool
    var isDownloaded: Bool
    var revision: String?
}

struct CloudCheckout: Sendable {
    let dossierID: UUID
    let revision: String?
    let archive: WorkspaceArchive
}

struct CloudCommitteeVersion: Identifiable, Codable, Sendable {
    let id: UUID
    let modifiedAt: Date
    let isConflict: Bool
    let hasLocalChanges: Bool
    let committees: [MeetingPurpose]
}

actor CloudSyncStore {
    nonisolated static let containerIdentifier = "iCloud.nl.commissiewijzer.app"

    private struct Entry: Codable, Sendable {
        var id: UUID
        var title: String
        var modifiedAt: Date
        var conflict = false
        var dirty = false
        var downloaded = true
        var revision: String?
        var editBaseRevision: String?
        var contentHash: String
    }
    private struct CommitteeEntry: Codable, Sendable {
        var id: UUID
        var modifiedAt: Date
        var conflict = false
        var dirty = true
        var revision: String?
        var contentHash: String
        var downloaded = true
    }
    private struct Manifest: Codable, Sendable {
        var accountHash: String
        var entries: [UUID: Entry] = [:]
        var committees: [UUID: CommitteeEntry] = [:]
    }

    private let directory: URL
    private let transport: any CloudSyncTransport
    private var identity: String?
    private var namespace: URL?
    private var manifest = Manifest(accountHash: "")
    private var generation: UInt64 = 0
    private var syncing = false

    init(directory: URL, transport: any CloudSyncTransport) {
        self.directory = directory
        self.transport = transport
    }

    func activate(allowAccountChange: Bool = false) async throws -> [CloudDossier] {
        let generationAtStart = generation
        let account = try await transport.accountIdentifier()
        guard generationAtStart == generation else { throw CloudSyncError.accountChanged }
        guard !account.isEmpty else { throw CloudSyncError.missingAccount }
        try await transport.activateAccount(account)
        guard generationAtStart == generation, try await transport.accountIdentifier() == account else {
            throw CloudSyncError.accountChanged
        }
        let accountHash = Self.sha256(Data(account.utf8))
        let index = directory.appendingPathComponent("CloudSync").appendingPathComponent("active-cache")
        if let previousHash = try? String(contentsOf: index, encoding: .utf8),
           previousHash != accountHash, !allowAccountChange {
            throw CloudSyncError.accountChanged
        }
        let folder = directory.appendingPathComponent("CloudSync", isDirectory: true)
            .appendingPathComponent(accountHash, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let manifestURL = folder.appendingPathComponent("manifest.json")
        var loaded = Manifest(accountHash: accountHash)
        if FileManager.default.fileExists(atPath: manifestURL.path) {
            do {
                loaded = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: manifestURL))
                guard loaded.accountHash == accountHash else { throw CloudSyncError.corruptCache }
                try verifyLocalFiles(loaded, at: folder)
            } catch let error as CloudSyncError { throw error }
            catch { throw CloudSyncError.corruptCache }
        }
        guard generationAtStart == generation else { throw CloudSyncError.accountChanged }
        identity = account
        namespace = folder
        manifest = loaded
        try atomicWrite(Data(accountHash.utf8), to: directory.appendingPathComponent("CloudSync").appendingPathComponent("active-cache"))
        return dossierList()
    }

    func deactivate() async {
        generation &+= 1
        identity = nil
        // Keep the disk namespace mounted for offline reading. No transport call is
        // possible without identity, and queued uploads remain isolated on disk.
    }

    func dossiers() async throws -> [CloudDossier] {
        if identity == nil { try loadCachedNamespaceIfNeeded() }
        guard namespace != nil else { return [] }
        return dossierList()
    }

    func save(_ archive: WorkspaceArchive, dossierID: UUID? = nil, baseRevision: String? = nil,
              allowOfflineCache: Bool = false) async throws -> CloudDossier {
        if identity == nil {
            guard allowOfflineCache else { throw CloudSyncError.notActivated }
            try loadCachedNamespaceIfNeeded()
            // Offline edits may only update a dossier already owned by this
            // cached account. Account verification is still required to send it.
            guard let dossierID, manifest.entries[dossierID]?.downloaded == true else { throw CloudSyncError.notActivated }
        }
        guard let folder = namespace else { throw CloudSyncError.notActivated }
        var clean: WorkspaceArchive
        do { clean = try archive.validatedForWriting() } catch { throw CloudSyncError.invalidArchive }
        clean.snapshotID = nil
        let payload: Data
        do { payload = try Self.canonicalArchiveData(clean) }
        catch { throw CloudSyncError.invalidArchive }
        guard payload.count <= 250_000_000 else { throw CloudSyncError.tooLarge }
        let hash = Self.sha256(payload)
        var id = dossierID ?? UUID()
        var existing = manifest.entries[id]
        var conflictCopy = false
        let supplied = Self.parseRevisionToken(baseRevision)
        var effectiveBaseRevision = supplied.serverRevision
        if dossierID != nil, let current = existing {
            let validBase: Bool
            if let localHash = supplied.localHash {
                validBase = current.contentHash == localHash
                if validBase { effectiveBaseRevision = current.editBaseRevision ?? current.revision }
            } else {
                validBase = current.revision == supplied.serverRevision
            }
            if !validBase { id = UUID(); existing = nil; conflictCopy = true }
        }
        let date = Date()
        let entry = Entry(id: id, title: archive.name, modifiedAt: date,
                          conflict: conflictCopy || (existing?.conflict ?? false), dirty: true, downloaded: true,
                          revision: existing?.revision, editBaseRevision: conflictCopy ? nil : effectiveBaseRevision,
                          contentHash: hash)
        try atomicWrite(payload, to: archiveURL(id, hash: hash, in: folder))
        manifest.entries[id] = entry
        try persist()
        if let oldHash = existing?.contentHash, oldHash != hash {
            try? FileManager.default.removeItem(at: archiveURL(id, hash: oldHash, in: folder))
        }
        return CloudDossier(id: id, title: entry.title, modifiedAt: date,
                            isConflict: entry.conflict, hasLocalChanges: true, isDownloaded: true,
                            revision: Self.revisionToken(server: entry.revision, hash: entry.contentHash))
    }

    func checkout(dossierID: UUID) async throws -> CloudCheckout {
        let loaded = try await loadArchive(dossierID: dossierID)
        return CloudCheckout(dossierID: dossierID,
            revision: Self.revisionToken(server: loaded.revision, hash: loaded.contentHash),
            archive: loaded.archive)
    }

    func archive(dossierID: UUID) async throws -> WorkspaceArchive {
        let loaded = try await loadArchive(dossierID: dossierID)
        return loaded.archive
    }

    private func loadArchive(dossierID: UUID) async throws -> (archive: WorkspaceArchive, revision: String?, contentHash: String) {
        if identity == nil { try loadCachedNamespaceIfNeeded() }
        guard let folder = namespace else { throw CloudSyncError.dossierMissing }
        guard var entry = manifest.entries[dossierID] else { throw CloudSyncError.dossierMissing }
        var data: Data?
        if entry.downloaded {
            let cached = try? Data(contentsOf: archiveURL(dossierID, hash: entry.contentHash, in: folder))
            if let cached, Self.sha256(cached) == entry.contentHash { data = cached }
            else if entry.dirty { throw CloudSyncError.corruptCache }
            else { entry.downloaded = false }
        }
        if data == nil, identity != nil, entry.revision != nil {
            let generationAtStart = generation
            let capturedHash = entry.contentHash
            let capturedRevision = entry.revision
            try await checkAccount()
            let fetched = try await transport.fetchArchive(id: dossierID)
            try await checkAccount(expectedGeneration: generationAtStart)
            guard Self.sha256(fetched.archive) == fetched.metadata.contentHash else { throw CloudSyncError.corruptCache }
            let value: WorkspaceArchive
            do { value = try JSONDecoder().decode(WorkspaceArchive.self, from: fetched.archive); try value.validate() }
            catch { throw CloudSyncError.invalidArchive }
            guard generation == generationAtStart, namespace == folder else { throw CloudSyncError.accountChanged }
            guard let latest = manifest.entries[dossierID] else { throw CloudSyncError.dossierMissing }
            if latest.contentHash != capturedHash || latest.revision != capturedRevision || latest.dirty {
                guard latest.downloaded, let currentData = try? Data(contentsOf: archiveURL(dossierID, hash: latest.contentHash, in: folder)),
                      Self.sha256(currentData) == latest.contentHash else { throw CloudSyncError.conflict }
                let currentArchive = try JSONDecoder().decode(WorkspaceArchive.self, from: currentData)
                try currentArchive.validate()
                return (currentArchive, latest.revision, latest.contentHash)
            }
            let previousHash = entry.contentHash
            try atomicWrite(fetched.archive, to: archiveURL(dossierID, hash: fetched.metadata.contentHash, in: folder))
            entry.downloaded = true
            entry.revision = fetched.metadata.revision
            entry.editBaseRevision = fetched.metadata.revision
            entry.contentHash = fetched.metadata.contentHash
            entry.title = fetched.metadata.title
            entry.modifiedAt = fetched.metadata.modifiedAt
            manifest.entries[dossierID] = entry
            try persist()
            if previousHash != fetched.metadata.contentHash {
                try? FileManager.default.removeItem(at: archiveURL(dossierID, hash: previousHash, in: folder))
            }
            return (value, fetched.metadata.revision, fetched.metadata.contentHash)
        }
        guard let data else { throw CloudSyncError.dossierMissing }
        do {
            let value = try JSONDecoder().decode(WorkspaceArchive.self, from: data)
            try value.validate()
            return (value, entry.revision, entry.contentHash)
        } catch { throw CloudSyncError.invalidArchive }
    }

    func synchronize(includeCommittees: Bool = true) async throws -> [CloudDossier] {
        guard identity != nil, namespace != nil else { throw CloudSyncError.notActivated }
        guard !syncing else { return dossierList() }
        syncing = true
        defer { syncing = false }
        let generationAtStart = generation
        try await checkAccount(expectedGeneration: generationAtStart)
        let remote = try await transport.listDossiers()
        try await checkAccount(expectedGeneration: generationAtStart)
        for remoteItem in remote {
            if Task.isCancelled || generationAtStart != generation { return dossierList() }
            guard let local = manifest.entries[remoteItem.id] else {
                manifest.entries[remoteItem.id] = Entry(id: remoteItem.id, title: remoteItem.title,
                    modifiedAt: remoteItem.modifiedAt, conflict: false, dirty: false, downloaded: false,
                    revision: remoteItem.revision, editBaseRevision: remoteItem.revision, contentHash: remoteItem.contentHash)
                continue
            }
            if local.dirty {
                if local.contentHash != remoteItem.contentHash,
                   local.editBaseRevision != remoteItem.revision {
                    try await forkLocal(local, generationAtStart: generationAtStart)
                    try await installRemoteArchive(id: remoteItem.id, metadata: remoteItem, expectedLocalHash: local.contentHash, generationAtStart: generationAtStart)
                } else if local.contentHash == remoteItem.contentHash {
                    var updated = local; updated.dirty = false; updated.revision = remoteItem.revision
                    updated.editBaseRevision = remoteItem.revision; manifest.entries[remoteItem.id] = updated
                }
            } else {
                if local.contentHash != remoteItem.contentHash && local.downloaded {
                    try await installRemoteArchive(id: remoteItem.id, metadata: remoteItem,
                        expectedLocalHash: local.contentHash, generationAtStart: generationAtStart)
                } else {
                    var updated = local
                    updated.title = remoteItem.title; updated.modifiedAt = remoteItem.modifiedAt
                    updated.revision = remoteItem.revision; updated.editBaseRevision = remoteItem.revision
                    updated.contentHash = remoteItem.contentHash
                    manifest.entries[remoteItem.id] = updated
                }
            }
        }
        try persist()

        if includeCommittees {
        try await checkAccount(expectedGeneration: generationAtStart)
        let remoteCommittees = try await transport.listCommitteeVersions()
        try await checkAccount(expectedGeneration: generationAtStart)
        for remoteVersion in remoteCommittees where manifest.committees[remoteVersion.id] == nil {
            manifest.committees[remoteVersion.id] = CommitteeEntry(id: remoteVersion.id,
                modifiedAt: remoteVersion.modifiedAt, conflict: false, dirty: false,
                revision: remoteVersion.revision, contentHash: remoteVersion.contentHash, downloaded: false)
        }
        for (id, initial) in manifest.committees where initial.dirty {
            if Task.isCancelled || generationAtStart != generation { return dossierList() }
            let payload = try Data(contentsOf: committeeURL(id, hash: initial.contentHash, in: namespace!))
            do {
                try await checkAccount(expectedGeneration: generationAtStart)
                let saved = try await transport.saveCommittees(id: id, modifiedAt: initial.modifiedAt,
                    contentHash: initial.contentHash, expectedRevision: initial.revision, payload: payload)
                try await checkAccount(expectedGeneration: generationAtStart)
                if var latest = manifest.committees[id], latest.contentHash == initial.contentHash {
                    latest.dirty = false; latest.revision = saved.revision; latest.downloaded = true
                    manifest.committees[id] = latest
                }
            } catch CloudSyncError.conflict {
                guard let stillQueued = manifest.committees[id], stillQueued.contentHash == initial.contentHash else { continue }
                let forkID = UUID()
                let fork = CommitteeEntry(id: forkID, modifiedAt: Date(), conflict: true, dirty: true,
                    revision: nil, contentHash: initial.contentHash, downloaded: true)
                try atomicWrite(payload, to: committeeURL(forkID, hash: initial.contentHash, in: namespace!))
                manifest.committees[forkID] = fork
                if var latest = manifest.committees[id] { latest.dirty = false; manifest.committees[id] = latest }
            }
            try persist()
        }
        try persist()

        }
        for (id, initial) in manifest.entries where initial.dirty {
            if Task.isCancelled || generationAtStart != generation { return dossierList() }
            guard let folder = namespace else { return dossierList() }
            let payload = try Data(contentsOf: archiveURL(id, hash: initial.contentHash, in: folder))
            let snapshotHash = initial.contentHash
            do {
                try await checkAccount(expectedGeneration: generationAtStart)
                let saved = try await transport.saveArchive(id: id, title: initial.title,
                    modifiedAt: initial.modifiedAt, contentHash: snapshotHash,
                    expectedRevision: initial.editBaseRevision, archive: payload)
                try await checkAccount(expectedGeneration: generationAtStart)
                if var latest = manifest.entries[id], latest.contentHash == snapshotHash {
                    latest.dirty = false; latest.revision = saved.revision; latest.editBaseRevision = saved.revision
                    manifest.entries[id] = latest
                } else if var latest = manifest.entries[id], latest.dirty,
                          latest.editBaseRevision == initial.editBaseRevision {
                    // The uploaded version is the parent of a newer local edit.
                    // Advance its CAS base without marking that descendant clean.
                    latest.revision = saved.revision
                    latest.editBaseRevision = saved.revision
                    manifest.entries[id] = latest
                }
            } catch CloudSyncError.conflict {
                guard let stillQueued = manifest.entries[id], stillQueued.contentHash == snapshotHash else { continue }
                try await forkLocal(stillQueued, generationAtStart: generationAtStart)
                try await checkAccount(expectedGeneration: generationAtStart)
                let currentRemote = (try await transport.listDossiers()).first(where: { $0.id == id })
                if let currentRemote {
                    try await checkAccount(expectedGeneration: generationAtStart)
                    try await installRemoteArchive(id: id, metadata: currentRemote, expectedLocalHash: snapshotHash, generationAtStart: generationAtStart)
                } else {
                    var latest = manifest.entries[id] ?? stillQueued
                    latest.dirty = false; manifest.entries[id] = latest
                }
            }
            try persist()
        }
        return dossierList()
    }

    func saveCommittees(_ committees: [MeetingPurpose]) async throws {
        guard identity != nil, let folder = namespace else { throw CloudSyncError.notActivated }
        guard committees.allSatisfy({ $0 != .raad }) else { throw CloudSyncError.invalidArchive }
        do { try committees.compactMap(\.committee).forEach { try $0.validate() } }
        catch { throw CloudSyncError.invalidArchive }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(committees)
        let id = UUID(), date = Date(), hash = Self.sha256(data)
        guard !manifest.committees.values.contains(where: { $0.contentHash == hash }) else { return }
        try atomicWrite(data, to: committeeURL(id, hash: hash, in: folder))
        manifest.committees[id] = CommitteeEntry(id: id, modifiedAt: date, dirty: true, contentHash: hash)
        try persist()
    }

    func committeeVersions() async throws -> [CloudCommitteeVersion] {
        if identity == nil { try loadCachedNamespaceIfNeeded() }
        guard let folder = namespace else { return [] }
        var result: [CloudCommitteeVersion] = []
        for originalEntry in Array(manifest.committees.values) {
            var entry = originalEntry
            let data: Data
            if FileManager.default.fileExists(atPath: committeeURL(entry.id, hash: entry.contentHash, in: folder).path) {
                data = try Data(contentsOf: committeeURL(entry.id, hash: entry.contentHash, in: folder))
            } else if !entry.dirty {
                guard identity != nil else { continue }
                let generationAtStart = generation
                try await checkAccount(expectedGeneration: generationAtStart)
                let downloaded = try await transport.fetchCommittees(id: entry.id)
                try await checkAccount(expectedGeneration: generationAtStart)
                guard generation == generationAtStart, namespace == folder,
                      manifest.committees[entry.id]?.contentHash == entry.contentHash else { throw CloudSyncError.accountChanged }
                data = downloaded.payload
                guard Self.sha256(data) == downloaded.metadata.contentHash,
                      downloaded.metadata.revision == entry.revision else { throw CloudSyncError.corruptCache }
                try atomicWrite(data, to: committeeURL(entry.id, hash: entry.contentHash, in: folder))
                entry.downloaded = true
                manifest.committees[entry.id] = entry
                try persist()
            } else { throw CloudSyncError.corruptCache }
            guard Self.sha256(data) == entry.contentHash else { throw CloudSyncError.corruptCache }
            let committees = try JSONDecoder().decode([MeetingPurpose].self, from: data)
            guard committees.allSatisfy({ $0 != .raad }) else { throw CloudSyncError.invalidArchive }
            do { try committees.compactMap(\.committee).forEach { try $0.validate() } }
            catch { throw CloudSyncError.invalidArchive }
            result.append(CloudCommitteeVersion(id: entry.id, modifiedAt: entry.modifiedAt,
                isConflict: entry.conflict, hasLocalChanges: entry.dirty, committees: committees))
        }
        return result.sorted { $0.modifiedAt > $1.modifiedAt }
    }

    private func dossierList() -> [CloudDossier] {
        manifest.entries.values.map { CloudDossier(id: $0.id, title: $0.title, modifiedAt: $0.modifiedAt,
            isConflict: $0.conflict, hasLocalChanges: $0.dirty, isDownloaded: $0.downloaded,
            revision: Self.revisionToken(server: $0.revision, hash: $0.contentHash)) }
            .sorted { $0.modifiedAt > $1.modifiedAt }
    }

    private func checkAccount(expectedGeneration: UInt64? = nil) async throws {
        guard let identity else { throw CloudSyncError.accountChanged }
        let expected = expectedGeneration ?? generation
        let current = try await transport.accountIdentifier()
        guard generation == expected, current == identity else { throw CloudSyncError.accountChanged }
    }

    private func forkLocal(_ entry: Entry, generationAtStart: UInt64) async throws {
        guard generation == generationAtStart, let folder = namespace else { return }
        let oldURL = archiveURL(entry.id, hash: entry.contentHash, in: folder)
        let bytes = try Data(contentsOf: oldURL)
        let forkID = UUID()
        let fork = Entry(id: forkID, title: "\(entry.title) (conflict)", modifiedAt: Date(), conflict: true,
                         dirty: true, downloaded: true, revision: nil, editBaseRevision: nil, contentHash: entry.contentHash)
        try atomicWrite(bytes, to: archiveURL(forkID, hash: entry.contentHash, in: folder))
        manifest.entries[forkID] = fork
        try persist()
    }

    private func installRemoteArchive(id: UUID, metadata: CloudRemoteDossier, expectedLocalHash: String,
                                      generationAtStart: UInt64) async throws {
        try await checkAccount(expectedGeneration: generationAtStart)
        let download = try await transport.fetchArchive(id: id)
        try await checkAccount(expectedGeneration: generationAtStart)
        guard generation == generationAtStart, let folder = namespace,
              Self.sha256(download.archive) == download.metadata.contentHash,
              download.metadata.revision == metadata.revision,
              download.metadata.contentHash == metadata.contentHash else { throw CloudSyncError.conflict }
        if let latest = manifest.entries[id], latest.dirty, latest.contentHash != expectedLocalHash { return }
        do {
            let value = try JSONDecoder().decode(WorkspaceArchive.self, from: download.archive)
            try value.validate()
        } catch { throw CloudSyncError.invalidArchive }
        let previousHash = manifest.entries[id]?.contentHash
        try atomicWrite(download.archive, to: archiveURL(id, hash: download.metadata.contentHash, in: folder))
        manifest.entries[id] = Entry(id: id, title: download.metadata.title, modifiedAt: download.metadata.modifiedAt,
            conflict: false, dirty: false, downloaded: true, revision: download.metadata.revision,
            editBaseRevision: download.metadata.revision, contentHash: download.metadata.contentHash)
        try persist()
        if let previousHash, previousHash != download.metadata.contentHash {
            try? FileManager.default.removeItem(at: archiveURL(id, hash: previousHash, in: folder))
        }
    }

    private func persist() throws {
        guard let namespace else { throw CloudSyncError.notActivated }
        let data = try JSONEncoder().encode(manifest)
        try atomicWrite(data, to: namespace.appendingPathComponent("manifest.json"))
    }

    private func loadCachedNamespaceIfNeeded() throws {
        guard namespace == nil else { return }
        let root = directory.appendingPathComponent("CloudSync", isDirectory: true)
        let index = root.appendingPathComponent("active-cache")
        guard let hash = try? String(contentsOf: index, encoding: .utf8),
              hash.count == 64, hash.allSatisfy({ $0.isHexDigit }) else { return }
        let folder = root.appendingPathComponent(hash, isDirectory: true)
        do {
            let data = try Data(contentsOf: folder.appendingPathComponent("manifest.json"))
            let loaded = try JSONDecoder().decode(Manifest.self, from: data)
            guard loaded.accountHash == hash else { throw CloudSyncError.corruptCache }
            try verifyLocalFiles(loaded, at: folder)
            namespace = folder
            manifest = loaded
        } catch let error as CloudSyncError { throw error }
        catch { throw CloudSyncError.corruptCache }
    }

    private func verifyLocalFiles(_ manifest: Manifest, at folder: URL) throws {
        for entry in manifest.entries.values where entry.downloaded {
            let url = archiveURL(entry.id, hash: entry.contentHash, in: folder)
            guard let data = try? Data(contentsOf: url), Self.sha256(data) == entry.contentHash else { throw CloudSyncError.corruptCache }
            do { let archive = try JSONDecoder().decode(WorkspaceArchive.self, from: data); try archive.validate() }
            catch { throw CloudSyncError.corruptCache }
        }
        for entry in manifest.committees.values where entry.dirty {
            let url = committeeURL(entry.id, hash: entry.contentHash, in: folder)
            guard let data = try? Data(contentsOf: url), Self.sha256(data) == entry.contentHash else { throw CloudSyncError.corruptCache }
        }
    }

    private func archiveURL(_ id: UUID, hash: String, in folder: URL) -> URL { folder.appendingPathComponent("\(id.uuidString)-\(hash).spdfwork") }
    private func committeeURL(_ id: UUID, hash: String, in folder: URL) -> URL { folder.appendingPathComponent("committee-\(id.uuidString)-\(hash).json") }
    private func atomicWrite(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
    private static func sha256(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    private static func canonicalArchiveData(_ archive: WorkspaceArchive) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let encoded = try encoder.encode(archive)
        guard var object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any] else { throw CloudSyncError.invalidArchive }
        if let starred = object["starred"] as? [String] { object["starred"] = starred.sorted() }
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }
    private static func revisionToken(server: String?, hash: String?) -> String? {
        guard let hash else { return nil }
        return "cw1:\(server ?? ""):\(hash)"
    }
    private static func parseRevisionToken(_ token: String?) -> (serverRevision: String?, localHash: String?) {
        guard let token, token.hasPrefix("cw1:"), let separator = token.dropFirst(4).lastIndex(of: ":") else {
            return (token, nil)
        }
        let server = String(token[token.index(token.startIndex, offsetBy: 4)..<separator])
        let hash = String(token[token.index(after: separator)...])
        return (server.isEmpty ? nil : server, hash)
    }
}
