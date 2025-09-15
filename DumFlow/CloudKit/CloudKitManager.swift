////
////  CloudKitManager.swift
////  DumFlow
////
////  Created by Isaac Herskowitz on 6/14/25.
////
//
//import CloudKit
//import Foundation
//
//class CloudKitManager: ObservableObject {
//    static let shared = CloudKitManager()
//    
//    private let container: CKContainer
//    let publicDatabase: CKDatabase
//    let privateDatabase: CKDatabase
//    
//    @Published var isSignedInToiCloud = false
//    @Published var error: CloudKitError?
//    
//    private init() {
//        container = CKContainer(identifier: "iCloud.com.isaacherskowitz.dumflow")
//        publicDatabase = container.publicCloudDatabase
//        privateDatabase = container.privateCloudDatabase
//        
//        checkiCloudStatus()
//    }
//    
//    // MARK: - iCloud Status
//    // MARK: - iCloud Status
//    func checkiCloudStatus() {
//        container.accountStatus { [weak self] status, error in
//            DispatchQueue.main.async {
//                switch status {
//                case .available:
//                    self?.isSignedInToiCloud = true
//                case .noAccount:
//                    self?.isSignedInToiCloud = false
//                    self?.error = CloudKitError.iCloudAccountNotAvailable
//                case .couldNotDetermine:
//                    self?.isSignedInToiCloud = false
//                    self?.error = CloudKitError.iCloudAccountNotAvailable
//                case .restricted:
//                    self?.isSignedInToiCloud = false
//                    self?.error = CloudKitError.iCloudAccountNotAvailable
//                case .temporarilyUnavailable:
//                    self?.isSignedInToiCloud = false
//                    self?.error = CloudKitError.iCloudAccountNotAvailable
//                @unknown default:
//                    self?.isSignedInToiCloud = false
//                    self?.error = CloudKitError.iCloudAccountNotAvailable
//                }
//            }
//        }
//    }
//    
//    // MARK: - User Management
//    func getCurrentUserID() async throws -> CKRecord.ID {
//        return try await container.userRecordID()
//    }
//    
//    func save<T>(_ item: T, to database: CKDatabase? = nil) async throws -> T where T: CloudKitConvertible {
//        let targetDatabase = database ?? publicDatabase
//        let record = item.toRecord()
//        let savedRecord = try await targetDatabase.save(record)
//        return try T(record: savedRecord)
//    }
//    
//    func fetch<T>(_ type: T.Type, with recordID: CKRecord.ID, from database: CKDatabase? = nil) async throws -> T where T: CloudKitConvertible {
//        let targetDatabase = database ?? publicDatabase
//        let record = try await targetDatabase.record(for: recordID)
//        return try T(record: record)
//    }
//    
//    func delete(_ recordID: CKRecord.ID, from database: CKDatabase? = nil) async throws {
//        let targetDatabase = database ?? publicDatabase
//        _ = try await targetDatabase.deleteRecord(withID: recordID)
//    }
//}
//
//protocol CloudKitConvertible {
//    init(record: CKRecord) throws
//    func toRecord() -> CKRecord
//}
//
