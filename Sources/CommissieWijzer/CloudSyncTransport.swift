import Foundation
import CryptoKit
import CloudKit
#if os(macOS)
import Security
#endif

struct CloudRemoteDossier: Sendable, Equatable {
    let id: UUID
    let title: String
    let modifiedAt: Date
    let revision: String
    let contentHash: String
}

struct CloudRemoteCommitteeVersion: Sendable, Equatable {
    let id: UUID
    let modifiedAt: Date
    let revision: String
    let contentHash: String
}

enum CloudSyncError: Error, LocalizedError, Sendable {
    case unavailable
    case previewBuild
    case missingAccount
    case restrictedAccount
    case accountChanged
    case notActivated
    case dossierMissing
    case conflict
    case corruptCache
    case invalidArchive
    case tooLarge
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .unavailable: "Deze installatie heeft geen geldige iCloud-bevoegdheid. Open een versie met een passend iCloud-profiel."
        case .previewBuild: "Deze lokale testversie heeft geen iCloud-toegang. Open de voor iCloud ondertekende versie van CommissieWijzer."
        case .missingAccount: "Log in bij iCloud om dossiers te synchroniseren."
        case .restrictedAccount: "Dit Apple-account heeft geen toegang tot iCloud voor deze app. Controleer de accountinstellingen of vraag de beheerder om hulp."
        case .accountChanged: "Het iCloud-account is gewijzigd. Activeer synchronisatie opnieuw voor dit account."
        case .notActivated: "Activeer iCloud-synchronisatie voordat je een dossier toevoegt."
        case .dossierMissing: "Dit dossier is niet beschikbaar in iCloud."
        case .conflict: "Een nieuwere versie is beschikbaar; beide versies zijn als afzonderlijke dossiers bewaard."
        case .corruptCache: "De lokale iCloud-synchronisatiegegevens zijn beschadigd. De lokale dossiers zijn behouden."
        case .invalidArchive: "Het ontvangen werkdocument is ongeldig en is niet geopend."
        case .tooLarge: "Dit werkdocument is te groot om met iCloud te synchroniseren."
        case .transport(let message): message
        }
    }
}

struct CloudArchiveDownload: Sendable {
    let archive: Data
    let metadata: CloudRemoteDossier
}

struct CloudCommitteeDownload: Sendable {
    let payload: Data
    let metadata: CloudRemoteCommitteeVersion
}

/// Only selected, already validated work is passed to this boundary. No AI,
/// keychain, preference enumeration, or logging of cloud responses occurs here.
protocol CloudSyncTransport: Sendable {
    func accountIdentifier() async throws -> String
    func activateAccount(_ accountIdentifier: String) async throws
    func listDossiers() async throws -> [CloudRemoteDossier]
    func fetchArchive(id: UUID) async throws -> CloudArchiveDownload
    func saveArchive(id: UUID, title: String, modifiedAt: Date, contentHash: String,
                     expectedRevision: String?, archive: Data) async throws -> CloudRemoteDossier
    func listCommitteeVersions() async throws -> [CloudRemoteCommitteeVersion]
    func fetchCommittees(id: UUID) async throws -> CloudCommitteeDownload
    func saveCommittees(id: UUID, modifiedAt: Date, contentHash: String,
                        expectedRevision: String?, payload: Data) async throws -> CloudRemoteCommitteeVersion
}

extension CloudSyncTransport {
    func activateAccount(_ accountIdentifier: String) async throws {}
}

actor CloudKitSyncTransport: CloudSyncTransport {
    nonisolated static let containerIdentifier = "iCloud.nl.commissiewijzer.app"
    private let zoneID = CKRecordZone.ID(zoneName: "CommissieWijzerPersonal", ownerName: CKCurrentUserDefaultName)
    private var boundAccount: String?
    private let configurationCheck: @Sendable () -> Bool

    init(configurationCheck: @escaping @Sendable () -> Bool = { CloudKitSyncTransport.isConfigured() }) {
        self.configurationCheck = configurationCheck
    }

    /// No CKContainer is constructed by an ordinary preview or test bundle.
    /// On iPad this signed build flag is set only by the profile-validating
    /// build path. iOS has no public SecTask entitlement inspection API.
    nonisolated static func isConfigured(in bundle: Bundle = .main) -> Bool {
        let flag = bundle.object(forInfoDictionaryKey: "CWCloudKitEnabled")
        let enabled = (flag as? Bool == true) || ["YES", "1", "true"].contains(flag as? String ?? "")
        guard enabled, bundle.bundleIdentifier == "nl.commissiewijzer.app" else { return false }
        #if os(macOS)
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return false }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else { return false }
        var information: CFDictionary?
        guard SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
              let info = information as? [String: Any],
              let entitlements = info[kSecCodeInfoEntitlementsDict as String] as? [String: Any],
              let containers = entitlements["com.apple.developer.icloud-container-identifiers"] as? [String],
              let services = entitlements["com.apple.developer.icloud-services"] as? [String] else { return false }
        return containers.contains(containerIdentifier) && services.contains("CloudKit")
        #else
        return true
        #endif
    }

    private func container() throws -> CKContainer {
        guard configurationCheck() else {
            let value = Bundle.main.object(forInfoDictionaryKey: "CWCloudKitEnabled")
            let flagEnabled = (value as? Bool == true) || ["YES", "1", "true"].contains(value as? String ?? "")
            throw flagEnabled ? CloudSyncError.unavailable : CloudSyncError.previewBuild
        }
        return CKContainer(identifier: Self.containerIdentifier)
    }

    func accountIdentifier() async throws -> String {
        do {
            try Task.checkCancellation()
            let c = try container()
            switch try await c.accountStatus() {
            case .available: break
            case .noAccount: throw CloudSyncError.missingAccount
            case .restricted: throw CloudSyncError.restrictedAccount
            case .temporarilyUnavailable, .couldNotDetermine:
                throw CloudSyncError.transport("De iCloud-accountstatus is tijdelijk niet beschikbaar. Controleer je verbinding en probeer opnieuw.")
            @unknown default:
                throw CloudSyncError.transport("De iCloud-accountstatus is niet bekend. Controleer je verbinding en probeer opnieuw.")
            }
            return try await c.userRecordID().recordName
        } catch { throw Self.presentable(error) }
    }

    func activateAccount(_ accountIdentifier: String) async throws {
        guard try await self.accountIdentifier() == accountIdentifier else { throw CloudSyncError.accountChanged }
        boundAccount = accountIdentifier
    }

    private func checkedDatabase() async throws -> CKDatabase {
        try Task.checkCancellation()
        guard let boundAccount else { throw CloudSyncError.notActivated }
        guard try await accountIdentifier() == boundAccount else { throw CloudSyncError.accountChanged }
        return try container().privateCloudDatabase
    }

    private func ensureZone() async throws -> CKDatabase {
        let db = try await checkedDatabase()
        do { _ = try await db.recordZone(for: zoneID) }
        catch let error as CKError where error.code == .zoneNotFound || error.code == .unknownItem {
            _ = try await checkedDatabase().save(CKRecordZone(zoneID: zoneID))
        }
        return db
    }

    /// Fetch every metadata page in a private zone, without downloading assets
    /// or requiring a production query index. Tokens page this snapshot only;
    /// refreshing starts from nil so missing/deleted heads are not resurrected.
    private func metadataRecords() async throws -> [CKRecord] {
        do {
            _ = try await ensureZone()
            var token: CKServerChangeToken?
            var records: [CKRecord.ID: CKRecord] = [:]
            var more = true
            while more {
                let db = try await checkedDatabase()
                let page = try await db.recordZoneChanges(inZoneWith: zoneID, since: token,
                    desiredKeys: ["dossierID", "versionID", "title", "modifiedAt", "contentHash", "formatVersion"], resultsLimit: 200)
                for (id, result) in page.modificationResultsByID { records[id] = try result.get().record }
                for deletion in page.deletions { records.removeValue(forKey: deletion.recordID) }
                token = page.changeToken
                more = page.moreComing
            }
            _ = try await checkedDatabase()
            return Array(records.values)
        } catch { throw Self.presentable(error) }
    }

    func listDossiers() async throws -> [CloudRemoteDossier] {
        try await metadataRecords().filter { $0.recordType == "Dossier" }.map(Self.dossierMetadata)
    }

    func listCommitteeVersions() async throws -> [CloudRemoteCommitteeVersion] {
        try await metadataRecords().filter { $0.recordType == "CommitteeVersion" }.map(Self.committeeMetadata)
    }

    private func recordID(_ id: UUID, committee: Bool = false) -> CKRecord.ID {
        CKRecord.ID(recordName: (committee ? "committee-" : "dossier-") + id.uuidString, zoneID: zoneID)
    }

    func fetchArchive(id: UUID) async throws -> CloudArchiveDownload {
        do {
            let record = try await checkedDatabase().record(for: recordID(id))
            let metadata = try Self.dossierMetadata(record)
            let data = try Self.asset(record, key: "archive", hash: metadata.contentHash)
            _ = try await checkedDatabase()
            return CloudArchiveDownload(archive: data, metadata: metadata)
        } catch { throw Self.presentable(error) }
    }

    func fetchCommittees(id: UUID) async throws -> CloudCommitteeDownload {
        do {
            let record = try await checkedDatabase().record(for: recordID(id, committee: true))
            let metadata = try Self.committeeMetadata(record)
            let data = try Self.asset(record, key: "payload", hash: metadata.contentHash)
            _ = try await checkedDatabase()
            return CloudCommitteeDownload(payload: data, metadata: metadata)
        } catch { throw Self.presentable(error) }
    }

    private func save(id: UUID, committee: Bool, title: String?, modifiedAt: Date,
                      contentHash: String, expectedRevision: String?, payload: Data) async throws -> CKRecord {
        do {
            guard payload.count <= 250_000_000,
                  SHA256.hash(data: payload).map({ String(format: "%02x", $0) }).joined() == contentHash else { throw CloudSyncError.invalidArchive }
            _ = try await ensureZone()
            let uuid = id
            let id = recordID(uuid, committee: committee)
            let record: CKRecord
            if let expectedRevision {
                do { record = try await checkedDatabase().record(for: id) }
                catch let error as CKError where error.code == .unknownItem { throw CloudSyncError.conflict }
                guard record.recordChangeTag == expectedRevision else { throw CloudSyncError.conflict }
            } else { record = CKRecord(recordType: committee ? "CommitteeVersion" : "Dossier", recordID: id) }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".cw-cloud")
            defer { try? FileManager.default.removeItem(at: url) }
            try payload.write(to: url, options: .atomic)
            record[committee ? "versionID" : "dossierID"] = uuid.uuidString as CKRecordValue
            if let title { record["title"] = title as CKRecordValue }
            record["modifiedAt"] = modifiedAt as CKRecordValue
            record["contentHash"] = contentHash as CKRecordValue
            record["formatVersion"] = 1 as CKRecordValue
            record[committee ? "payload" : "archive"] = CKAsset(fileURL: url)
            let result = try await checkedDatabase().modifyRecords(saving: [record], deleting: [], savePolicy: .ifServerRecordUnchanged, atomically: true)
            guard let saved = result.saveResults[id] else { throw CloudSyncError.conflict }
            let value = try saved.get()
            _ = try await checkedDatabase()
            return value
        } catch { throw Self.presentable(error) }
    }

    func saveArchive(id: UUID, title: String, modifiedAt: Date, contentHash: String,
                     expectedRevision: String?, archive: Data) async throws -> CloudRemoteDossier {
        try Self.dossierMetadata(await save(id: id, committee: false, title: title, modifiedAt: modifiedAt,
            contentHash: contentHash, expectedRevision: expectedRevision, payload: archive))
    }

    func saveCommittees(id: UUID, modifiedAt: Date, contentHash: String,
                        expectedRevision: String?, payload: Data) async throws -> CloudRemoteCommitteeVersion {
        try Self.committeeMetadata(await save(id: id, committee: true, title: nil, modifiedAt: modifiedAt,
            contentHash: contentHash, expectedRevision: expectedRevision, payload: payload))
    }

    private static func dossierMetadata(_ record: CKRecord) throws -> CloudRemoteDossier {
        guard let id = UUID(uuidString: record["dossierID"] as? String ?? ""),
              let title = record["title"] as? String, let date = record["modifiedAt"] as? Date,
              let hash = record["contentHash"] as? String, hash.count == 64,
              let revision = record.recordChangeTag,
              record.recordID.recordName == "dossier-" + id.uuidString else { throw CloudSyncError.invalidArchive }
        return CloudRemoteDossier(id: id, title: title, modifiedAt: date, revision: revision, contentHash: hash)
    }

    private static func committeeMetadata(_ record: CKRecord) throws -> CloudRemoteCommitteeVersion {
        guard let id = UUID(uuidString: record["versionID"] as? String ?? ""),
              let date = record["modifiedAt"] as? Date, let hash = record["contentHash"] as? String,
              hash.count == 64, let revision = record.recordChangeTag,
              record.recordID.recordName == "committee-" + id.uuidString else { throw CloudSyncError.invalidArchive }
        return CloudRemoteCommitteeVersion(id: id, modifiedAt: date, revision: revision, contentHash: hash)
    }

    private static func asset(_ record: CKRecord, key: String, hash: String) throws -> Data {
        guard let asset = record[key] as? CKAsset, let url = asset.fileURL else { throw CloudSyncError.dossierMissing }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= 250_000_000 else { throw CloudSyncError.tooLarge }
        let data = try Data(contentsOf: url)
        guard SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == hash else { throw CloudSyncError.invalidArchive }
        return data
    }

    /// Apple errors may contain private paths, record identifiers, or server
    /// responses. Show fixed messages and retain no such diagnostic payloads.
    nonisolated static func presentable(_ error: Error) -> Error {
        if error is CancellationError || error is CloudSyncError { return error }
        guard let cloud = error as? CKError else { return CloudSyncError.transport("iCloud kon de bewerking niet afronden. Je lokale werk is behouden. Probeer het opnieuw.") }
        if cloud.code == .partialFailure, let children = cloud.partialErrorsByItemID,
           let child = children.values.first { return presentable(child) }
        switch cloud.code {
        case .serverRecordChanged: return CloudSyncError.conflict
        case .notAuthenticated: return CloudSyncError.missingAccount
        case .quotaExceeded: return CloudSyncError.transport("Je iCloud-opslag is vol. Je lokale wijzigingen zijn behouden; maak ruimte vrij en probeer het opnieuw.")
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .accountTemporarilyUnavailable:
            return CloudSyncError.transport("iCloud is tijdelijk niet bereikbaar. Je lokale wijzigingen wachten op synchronisatie.")
        case .requestRateLimited, .zoneBusy:
            return CloudSyncError.transport("iCloud vraagt om even te wachten. Je lokale wijzigingen zijn behouden; probeer het later opnieuw.")
        case .permissionFailure, .badContainer, .missingEntitlement:
            return CloudSyncError.unavailable
        case .unknownItem: return CloudSyncError.dossierMissing
        default: return CloudSyncError.transport("iCloud kon de bewerking niet afronden. Je lokale werk is behouden. Probeer het opnieuw.")
        }
    }
}
