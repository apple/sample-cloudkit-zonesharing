//
//  ViewModel.swift
//  (cloudkit-samples) Zone Sharing
//

import Foundation
import CloudKit
import OSLog

@MainActor
final class ViewModel: ObservableObject {

    // MARK: - Error

    enum ViewModelError: Error {
        case invalidRemoteShare
    }

    // MARK: - State

    enum State {
        case loading
        case loaded(privateGroups: [ContactGroup], sharedGroups: [ContactGroup])
        case error(Error)
    }

    // MARK: - Properties

    /// State directly observable by our view.
    @Published private(set) var state: State = .loading
    /// Use the specified iCloud container ID, which should also be present in the entitlements file.
    lazy var container = CKContainer(identifier: Config.containerIdentifier)
    /// This project uses the user's private database.
    private lazy var database = container.privateCloudDatabase

    // MARK: - Init

    nonisolated init() {}

    /// Initializer to provide explicit state (e.g. for previews).
    init(state: State) {
        self.state = state
    }

    // MARK: - API

    /// Fetches contacts from the remote databases and updates local state.
    func refresh() async throws {
        state = .loading
        do {
            let (privateContacts, sharedContacts) = try await fetchPrivateAndSharedContacts()
            state = .loaded(privateGroups: privateContacts, sharedGroups: sharedContacts)
        } catch {
            state = .error(error)
        }
    }
    
    /// Fetches both private and shared contacts in parallel.
    /// - Returns: A tuple containing separated private and shared contacts.
    func fetchPrivateAndSharedContacts() async throws -> (private: [ContactGroup], shared: [ContactGroup]) {
        // Determine zones for each set of contacts.
        // In the Private DB, we want to ignore the default zone.
        let privateZones = try await database.allRecordZones()
            .filter { $0.zoneID != CKRecordZone.default().zoneID }
        let sharedZones = try await container.sharedCloudDatabase.allRecordZones()

        // This will run each of these operations in parallel.
        async let privateContacts = fetchContacts(scope: .private, in: privateZones)
        async let sharedContacts = fetchContacts(scope: .shared, in: sharedZones)

        return (private: try await privateContacts, shared: try await sharedContacts)
    }

    /// Adds a new Contact to the database.
    /// - Parameters:
    ///   - name: Name of the Contact.
    ///   - phoneNumber: Phone number of the contact.
    ///   - group: Group name the Contact should belong to.
    func addContact(name: String, phoneNumber: String, group: String) async throws {
        do {
            // Ensure zone exists first.
            let zone = CKRecordZone(zoneName: group)
            try await database.save(zone)
            
            let id = CKRecord.ID(zoneID: zone.zoneID)
            let contactRecord = CKRecord(recordType: "SharedContact", recordID: id)
            contactRecord["name"] = name
            contactRecord["phoneNumber"] = phoneNumber

            try await database.save(contactRecord)
        } catch {
            debugPrint("ERROR: Failed to save new Contact: \(error)")
            throw error
        }
    }

    /// Fetches an existing `CKShare` on a group zone, or creates a new one in preparation to share a group of contacts with another user.
    /// - Parameters:
    ///   - contactGroup: Group of Contacts to share.
    ///   - completionHandler: Handler to process a `success` or `failure` result.
    func fetchOrCreateShare(contactGroup: ContactGroup) async throws -> (CKShare, CKContainer) {
        guard let existingShare = contactGroup.zone.share else {
            let share = CKShare(recordZoneID: contactGroup.zone.zoneID)
            share[CKShare.SystemFieldKey.title] = "Contact Group: \(contactGroup.name)"
            _ = try await database.modifyRecords(saving: [share], deleting: [])
            return (share, container)
        }

        guard let share = try await database.record(for: existingShare.recordID) as? CKShare else {
            throw ViewModelError.invalidRemoteShare
        }

        return (share, container)
    }

    // MARK: - Private

    /// Fetches grouped contacts for a given set of zones in a given database scope.
    /// - Parameters:
    ///   - scope: Database scope to fetch from.
    ///   - zones: Record zones to fetch contacts from.
    /// - Returns: An array of grouped contacts (a zone/group name and an array of `Contact` objects).
    private func fetchContacts(
        scope: CKDatabase.Scope,
        in zones: [CKRecordZone]
    ) async throws -> [ContactGroup] {
        guard !zones.isEmpty else {
            return []
        }

        let database = container.database(with: scope)
        var allContacts: [ContactGroup] = []

        // Inner function retrieving and converting all Contact records for a single zone.
        @Sendable func contactsInZone(_ zone: CKRecordZone) async throws -> [Contact] {
            if zone.zoneID == CKRecordZone.default().zoneID {
                return []
            }

            var allContacts: [Contact] = []

            /// `recordZoneChanges` can return multiple consecutive changesets before completing, so
            /// we use a loop to process multiple results if needed, indicated by the `moreComing` flag.
            var awaitingChanges = true
            /// After each loop, if more changes are coming, they are retrieved by using the `changeToken` property.
            var nextChangeToken: CKServerChangeToken? = nil

            while awaitingChanges {
                let zoneChanges = try await database.recordZoneChanges(inZoneWith: zone.zoneID, since: nextChangeToken)
                let contacts = zoneChanges.modificationResultsByID.values
                    .compactMap { try? $0.get().record }
                    .compactMap { Contact(record: $0) }
                allContacts.append(contentsOf: contacts)

                awaitingChanges = zoneChanges.moreComing
                nextChangeToken = zoneChanges.changeToken
            }

            return allContacts
        }

        // Using this task group, fetch each zone's contacts in parallel.
        try await withThrowingTaskGroup(of: (CKRecordZone, [Contact]).self) { group in
            for zone in zones {
                group.addTask {
                    (zone, try await contactsInZone(zone))
                }
            }

            // As each result comes back, append it to a combined array to finally return.
            for try await (zone, contactsResult) in group {
                allContacts.append(ContactGroup(zone: zone, contacts: contactsResult))
            }
        }

        return allContacts
    }
}
