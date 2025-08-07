import SwiftUI
import OrbitsKit

struct PersonPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedPerson: Person?
    let persons: [Person]
    @State private var searchText = ""
    
    var filteredPersons: [Person] {
        if searchText.isEmpty {
            return persons
        } else {
            return persons.filter { person in
                let name = person.displayName ?? person.contactIdentifier
                let phone = person.phoneNumber ?? ""
                return name.localizedCaseInsensitiveContains(searchText) ||
                       phone.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(filteredPersons) { person in
                    Button {
                        selectedPerson = person
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(person.displayName ?? person.contactIdentifier)
                                    .font(.headline)
                                
                                if let phoneNumber = person.phoneNumber {
                                    Text(formatPhoneNumber(phoneNumber))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else if person.displayName != nil {
                                    Text(person.contactIdentifier)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            if selectedPerson?.id == person.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .searchable(text: $searchText, prompt: "Search contacts")
            .navigationTitle("Select Person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formatPhoneNumber(_ phoneNumber: String) -> String {
        let cleaned = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        if cleaned.count == 10 {
            let index0 = cleaned.startIndex
            let index3 = cleaned.index(cleaned.startIndex, offsetBy: 3)
            let index6 = cleaned.index(cleaned.startIndex, offsetBy: 6)
            let index10 = cleaned.endIndex
            
            return "(\(cleaned[index0..<index3])) \(cleaned[index3..<index6])-\(cleaned[index6..<index10])"
        } else if cleaned.count == 11 && cleaned.hasPrefix("1") {
            let withoutCountryCode = String(cleaned.dropFirst())
            return formatPhoneNumber(withoutCountryCode)
        } else {
            return phoneNumber
        }
    }
}