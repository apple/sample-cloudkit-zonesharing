//
//  ContactGroup.swift
//  (cloudkit-samples) Zone Sharing
//

import Foundation
import CloudKit

struct ContactGroup {
    let zone: CKRecordZone
    let contacts: [Contact]
    
    var name: String {
        zone.zoneID.zoneName
    }
}

extension ContactGroup: Identifiable {
    var id: String {
        name
    }
}
