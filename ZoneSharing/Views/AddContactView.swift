//
//  AddContactView.swift
//  (cloudkit-samples) Zone Sharing
//

import Foundation
import SwiftUI

/// View for adding new contacts.
struct AddContactView: View {
    @State private var nameInput: String = ""
    @State private var phoneInput: String = ""
    @State private var groupInput: String = ""

    /// Callback after user selects to add contact with given name and phone number.
    let onAdd: ((String, String, String) async throws -> Void)?
    /// Callback after user cancels.
    let onCancel: (() -> Void)?

    var body: some View {
        NavigationView {
            VStack {
                TextField("Full Name", text: $nameInput)
                    .textContentType(.name)
                TextField("Phone Number", text: $phoneInput)
                    .textContentType(.telephoneNumber)
                TextField("Group", text: $groupInput)
                Spacer()
            }
            .padding()
            .navigationTitle("Add Contact")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: { onCancel?() })
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: { Task { try? await onAdd?(nameInput, phoneInput, groupInput) } })
                        .disabled(nameInput.isEmpty || phoneInput.isEmpty || groupInput.isEmpty)
                }
            }
        }
    }
}
