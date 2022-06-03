//
//  ZoneSharingTests.swift
//  ZoneSharingTests
//

import XCTest
import CloudKit
@testable import ZoneSharing

class ZoneSharingTests: XCTestCase {

    let viewModel = ViewModel()
    var idsToDelete: [CKRecord.ID] = []
    var zoneIDsToDelete: [CKRecordZone.ID] = []

    // MARK: - Setup & Tear Down

    override func tearDownWithError() throws {
        guard !idsToDelete.isEmpty else {
            return
        }

        let container = CKContainer(identifier: Config.containerIdentifier)
        let database = container.privateCloudDatabase
        let deleteExpectation = expectation(description: "Expect CloudKit to delete testing records")

        Task {
            _ = try await database.modifyRecords(saving: [], deleting: idsToDelete)
            _ = try await database.modifyRecordZones(saving: [], deleting: zoneIDsToDelete)
            idsToDelete = []
            zoneIDsToDelete = []
            deleteExpectation.fulfill()
        }

        waitForExpectations(timeout: 10, handler: nil)
    }

    // MARK: - CloudKit Readiness

    func test_CloudKitReadiness() async throws {
        // Fetch zones from the Private Database of the CKContainer for the current user to test for valid/ready state
        let container = CKContainer(identifier: Config.containerIdentifier)
        let database = container.privateCloudDatabase

        do {
            _ = try await database.allRecordZones()
        } catch let error as CKError {
            switch error.code {
            case .badContainer, .badDatabase:
                XCTFail("Create or select a CloudKit container in this app target's Signing & Capabilities in Xcode")

            case .permissionFailure, .notAuthenticated:
                XCTFail("Simulator or device running this app needs a signed-in iCloud account")

            default:
                XCTFail("CKError: \(error)")
            }
        }
    }

    // MARK: - CKShare Creation

    func testCreatingShare() async throws {
        // Create a temporary contact to create the share on.
        try await createTestContact()
        // Fetch private contacts, which should now contain the temporary contact.
        let privateContacts = try await fetchPrivateContacts()
        
        // Find the group of our test Contact.
        guard let testContactGroup = privateContacts.first(where: { $0.name == testContactGroup }) else {
            XCTFail("No matching test Contact Group (zone) found after fetching private contacts")
            return
        }
        
        // Find the test Contact in the group.
        guard let testContact = testContactGroup.contacts.first(where: { $0.name == testContactName }) else {
            XCTFail("No matching test Contact found after fetching private contacts")
            return
        }

        idsToDelete.append(testContact.associatedRecord.recordID)
        zoneIDsToDelete.append(testContactGroup.zone.zoneID)

        let (share, _) = try await viewModel.fetchOrCreateShare(contactGroup: testContactGroup)

        idsToDelete.append(share.recordID)
    }

    // MARK: - Helpers

    /// For testing creating a `CKShare`, we need to create a `Contact` with a name we can reference later.
    private lazy var testContactName: String = {
        "Test\(UUID().uuidString)"
    }()
    
    /// We also need a contact group name for our test contact.
    private lazy var testContactGroup: String = {
        "Group\(UUID().uuidString)"
    }()

    /// Simple function to create and save a new `Contact` to test with. Immediately fails on any error.
    private func createTestContact() async throws {
        try await viewModel.addContact(name: testContactName, phoneNumber: "555-123-4567", group: testContactGroup)
    }

    /// Uses the ViewModel to fetch private contacts. Immediately fails on any error.
    /// - Parameter completion: Handler called on completion.
    private func fetchPrivateContacts() async throws -> [ContactGroup] {
        try await viewModel.fetchPrivateAndSharedContacts().private
    }
}
