# CloudKit Samples: Zone Sharing

### Goals

This project demonstrates sharing CloudKit records across user accounts with the zone sharing model, as opposed to the hierarchical model used by the other CloudKit Sharing sample project [here](https://github.com/apple/cloudkit-sample-sharing). This project extends the Sharing sample by organizing Contacts into groups using CloudKit Record Zones, and implements sharing those zones with other users. Participating users will have access to any Contact record in that zone.

### Prerequisites

* A Mac with [Xcode 13](https://developer.apple.com/xcode/) (or later) installed is required to build and test this project.
* An active [Apple Developer Program membership](https://developer.apple.com/support/compare-memberships/) is needed to create a CloudKit container.

### Setup Instructions

* Ensure the simulator or device you run the project on is signed in to an Apple ID account with iCloud enabled. This can be done in the Settings app.
* If you wish to run the app on a device, ensure the correct developer team is selected in the “Signing & Capabilities” tab of the Sharing app target, and a valid iCloud container is selected under the “iCloud” section.

#### Using Your Own iCloud Container

* Create a new iCloud container through Xcode’s “Signing & Capabilities” tab of the Sharing app target.
* Update the `containerIdentifier` property in [Config.swift](ZoneSharing/App/Config.swift) with your new iCloud container ID.

### How it Works

#### User One: Initiating the Share

* On either a device or simulator with a signed-in iCloud account, User One creates a set of Contact records with the same group name through the UI. Contacts are saved to the user’s private iCloud database with the `addContact(name:phoneNumber:group)` function in ViewModel.swift.

* After the Contacts list is refreshed, the newly added Contact will appear in a section of the list based on its group name.

* Private groups (sets of Contacts owned by the active user) have a “Share Group” button in the section footer. Tapping this button creates a `CKShare` (or fetches an existing one if the group has been shared before), and the `CloudSharingView` is displayed which wraps [UICloudSharingController](https://developer.apple.com/documentation/uikit/uicloudsharingcontroller) in a SwiftUI compatible view. This view allows the user to configure share options and send or copy the share link to share with User Two.

#### User Two: Accepting the Share Invitation

* On a separate device with a different signed-in iCloud account, User Two accepts the share by following the link provided by User One.

* The link initiates a prompt on the user’s device to accept the share, which launches the ZoneSharing app and accepts the share through a database operation defined in SceneDelegate’s `userDidAcceptCloudKitShareWith` delegate callback.

* After the share is accepted and the UI is refreshed, the shared group of Contacts will display in User Two’s Contacts list as a Shared Group, below that user’s private contacts.

### Further Reading

* [Sharing CloudKit Data with Other iCloud Users](https://developer.apple.com/documentation/cloudkit/shared_records/sharing_cloudkit_data_with_other_icloud_users)
* [`CKShare.init(recordZoneID:)` Documentation](https://developer.apple.com/documentation/cloudkit/ckshare/3746825-init)
