import SwiftUI
import OrbitsKit

struct PersonPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedPerson: Person?
    let persons: [Person]
    @State private var searchText = ""
    @State private var personTags: [UUID: [Tag]] = [:]
    
    private let supabaseService = SupabaseService(client: SupabaseManager.shared.client)
    
    var filteredPersons: [Person] {
        if searchText.isEmpty {
            return persons
        } else {
            return persons.filter { person in
                let name = person.displayName ?? person.contactIdentifier
                let phone = person.phoneNumber ?? ""
                let tags = personTags[person.id]?.map { $0.label }.joined(separator: " ") ?? ""
                return name.localizedCaseInsensitiveContains(searchText) ||
                       phone.localizedCaseInsensitiveContains(searchText) ||
                       tags.localizedCaseInsensitiveContains(searchText)
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
                                
                                if let tags = personTags[person.id], !tags.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 4) {
                                            ForEach(tags) { tag in
                                                Text(tag.label)
                                                    .font(.caption2)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 2)
                                                    .background(Color.blue.opacity(0.1))
                                                    .foregroundColor(.blue)
                                                    .cornerRadius(8)
                                            }
                                        }
                                    }
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
        .task {
            await loadTagsForPersons()
        }
    }
    
    private func loadTagsForPersons() async {
        // Load all tags in a single batch request instead of individual requests
        do {
            let allTags = try await supabaseService.fetchTags()
            let personTagPairs = try await supabaseService.fetchAllPersonTags()
            
            await MainActor.run {
                // Build a mapping of person ID to their tags
                var tagMapping: [UUID: [Tag]] = [:]
                
                for pair in personTagPairs {
                    if let tag = allTags.first(where: { $0.id == pair.tagId }) {
                        if tagMapping[pair.personId] == nil {
                            tagMapping[pair.personId] = []
                        }
                        tagMapping[pair.personId]?.append(tag)
                    }
                }
                
                self.personTags = tagMapping
            }
        } catch {
            print("Failed to load tags: \(error)")
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