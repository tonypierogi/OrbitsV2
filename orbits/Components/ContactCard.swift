import SwiftUI
import OrbitsKit

struct ContactCard: View {
    let person: Person
    let tags: [Tag]
    let onTap: () -> Void
    let onMessage: () -> Void
    
    init(person: Person, tags: [Tag] = [], onTap: @escaping () -> Void, onMessage: @escaping () -> Void = {}) {
        self.person = person
        self.tags = tags
        self.onTap = onTap
        self.onMessage = onMessage
    }
    
    private var daysSinceLastContact: Int? {
        guard let lastMessageDate = person.lastMessageDate else { return nil }
        return Calendar.current.dateComponents([.day], from: lastMessageDate, to: Date()).day
    }
    
    private var isOverdue: Bool {
        guard let orbit = person.orbit,
              let days = daysSinceLastContact else { return false }
        return days > orbit.intervalDays
    }
    
    private var daysOverdue: Int? {
        guard let orbit = person.orbit,
              let days = daysSinceLastContact else { return nil }
        let overdue = days - orbit.intervalDays
        return overdue > 0 ? overdue : nil
    }
    
    private var statusColor: Color {
        guard let orbit = person.orbit,
              let days = daysSinceLastContact else { return .gray }
        
        if days > orbit.intervalDays {
            return .red
        } else if days > orbit.intervalDays - orbit.slackDays {
            return .orange
        } else {
            return .green
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile image or initials
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 48, height: 48)
                
                Text(initials)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // Name
                Text(person.displayName ?? person.contactIdentifier)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                // Status row - simplified
                HStack(spacing: 4) {
                    Image(systemName: "message")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    Text("Texted \(daysSinceLastContact ?? 0) days ago")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                // Tags row - temporarily disabled for performance
                // Will be re-enabled with optimized fetching
                /*
                if !tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(tags.prefix(3)) { tag in
                                Text(tag.label)
                                    .font(.system(size: 11))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .clipShape(Capsule())
                            }
                            
                            if tags.count > 3 {
                                Text("+\(tags.count - 3)")
                                    .font(.system(size: 11))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.gray.opacity(0.1))
                                    .foregroundColor(.gray)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                */
            }
            
            Spacer(minLength: 8)
            
            // Right side items
            HStack(spacing: 8) {
                // Message button
                Button(action: {
                    onMessage()
                }) {
                    Image(systemName: "message.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
                .buttonStyle(BorderlessButtonStyle()) // Prevents button from capturing the entire row tap
                
                // Status indicator
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(16)
        .frame(minHeight: 80)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .contentShape(Rectangle())
    }
    
    private var initials: String {
        guard let displayName = person.displayName else { return "?" }
        let components = displayName.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1)).uppercased() + String(components[1].prefix(1)).uppercased()
        } else if let first = components.first {
            return String(first.prefix(1)).uppercased()
        }
        return "?"
    }
}

struct ContactCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            ContactCard(
                person: Person(
                    userId: UUID(),
                    contactIdentifier: "john@example.com",
                    displayName: "John Doe",
                    orbitId: UUID(),
                    unreadCount: 3,
                    lastMessageAt: Date().addingTimeInterval(-86400 * 15),
                    orbit: Orbit(
                        userId: UUID(),
                        name: "Near",
                        intervalDays: 14,
                        slackDays: 7,
                        position: 1
                    )
                ),
                onTap: {},
                onMessage: {}
            )
            
            ContactCard(
                person: Person(
                    userId: UUID(),
                    contactIdentifier: "jane@example.com",
                    displayName: "Jane Smith",
                    orbitId: UUID(),
                    lastMessageAt: Date().addingTimeInterval(-86400 * 5),
                    orbit: Orbit(
                        userId: UUID(),
                        name: "Near",
                        intervalDays: 14,
                        slackDays: 7,
                        position: 1
                    )
                ),
                onTap: {},
                onMessage: {}
            )
        }
        .padding()
    }
}