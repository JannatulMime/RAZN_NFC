//
//  AppVersionService.swift
//  RAZN NFC
//

import Foundation
import FirebaseFirestore

protocol AppVersionFetching: Sendable {
    func fetchConfig() async throws -> AppVersionConfig
}

protocol InstalledVersionProviding: Sendable {
    var shortVersionString: String? { get }
}

struct BundleInstalledVersionProvider: InstalledVersionProviding {
    let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    var shortVersionString: String? {
        bundle.infoDictionary?["CFBundleShortVersionString"] as? String
    }
}

/// Fetches `app_config/razn_ios` from Firestore using a server-backed read.
final class AppVersionService: AppVersionFetching, @unchecked Sendable {
    static let collectionPath = "app_config"
    static let documentID = "razn_ios"

    private let db: Firestore

    init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    func fetchConfig() async throws -> AppVersionConfig {
        let reference = db.collection(Self.collectionPath).document(Self.documentID)
        do {
            let snapshot = try await reference.getDocument(source: .server)
            guard snapshot.exists, let data = snapshot.data() else {
                throw AppVersionCheckError.documentMissing
            }
            do {
                return try AppVersionConfig(firestoreData: data)
            } catch let error as AppVersionConfig.ValidationError {
                throw AppVersionCheckError.invalidConfiguration(error)
            }
        } catch let error as AppVersionCheckError {
            throw error
        } catch {
            throw AppVersionCheckError.networkUnavailable
        }
    }
}
