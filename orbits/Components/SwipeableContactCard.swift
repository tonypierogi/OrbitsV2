import SwiftUI
import OrbitsKit

struct SwipeableContactCard: View {
    let person: Person
    let tags: [Tag]
    let onTap: () -> Void
    let onMessage: () -> Void
    let onRemoveOrbit: () async -> Void
    let onSnooze: () async -> Void
    
    @State private var offset: CGFloat = 0
    @GestureState private var dragOffset: CGFloat = 0
    @State private var isTapped = false
    
    private let swipeThreshold: CGFloat = 40
    private let actionButtonWidth: CGFloat = 90
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Background layer with actions
            HStack(spacing: 0) {
                // Remove Orbit action (left swipe reveals)
                Button(action: {
                    Task {
                        withAnimation(.easeOut(duration: 0.2)) {
                            offset = 0
                        }
                        await onRemoveOrbit()
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                        Text("Remove")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(width: actionButtonWidth)
                    .frame(maxHeight: .infinity)
                }
                .background(Color.red)
                
                Spacer()
                
                // Snooze action (right swipe reveals)
                Button(action: {
                    Task {
                        withAnimation(.easeOut(duration: 0.2)) {
                            offset = 0
                        }
                        await onSnooze()
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.title2)
                        Text("Snooze")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(width: actionButtonWidth)
                    .frame(maxHeight: .infinity)
                }
                .background(Color.orange)
            }
            .frame(height: 80)
            .cornerRadius(16)
            
            // Main card content
            ContactCard(
                person: person,
                tags: tags,
                onTap: {
                    if offset != 0 {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            offset = 0
                        }
                    } else {
                        isTapped = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isTapped = false
                            onTap()
                        }
                    }
                },
                onMessage: onMessage
            )
            .offset(x: offset + dragOffset)
            .allowsHitTesting(!isTapped) // Prevent interaction during navigation
            .gesture(
                DragGesture(minimumDistance: 5, coordinateSpace: .local)
                    .updating($dragOffset) { value, state, _ in
                        // Only process horizontal swipes, ignore vertical scrolling
                        let horizontalAmount = abs(value.translation.width)
                        let verticalAmount = abs(value.translation.height)
                        
                        // Only process if horizontal movement is significant (2:1 ratio)
                        if horizontalAmount > verticalAmount * 1.5 {
                            if offset == 0 {
                                state = value.translation.width
                            } else if offset > 0 && value.translation.width < 0 {
                                // Allow dragging back from right swipe
                                state = value.translation.width
                            } else if offset < 0 && value.translation.width > 0 {
                                // Allow dragging back from left swipe
                                state = value.translation.width
                            }
                        }
                    }
                    .onEnded { value in
                        let horizontalAmount = abs(value.translation.width)
                        let verticalAmount = abs(value.translation.height)
                        
                        // Only process if horizontal movement is greater than vertical
                        if horizontalAmount > verticalAmount {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                let dragThreshold: CGFloat = 50
                                let currentOffset = offset + value.translation.width
                                
                                if currentOffset > dragThreshold {
                                    // Reveal left action (remove orbit)
                                    offset = actionButtonWidth
                                } else if currentOffset < -dragThreshold {
                                    // Reveal right action (snooze)
                                    offset = -actionButtonWidth
                                } else {
                                    // Snap back to center
                                    offset = 0
                                }
                            }
                        }
                    }
            )
        }
        .clipped()
    }
}

struct SwipeableContactCard_Previews: PreviewProvider {
    static var previews: some View {
        SwipeableContactCard(
            person: Person(
                userId: UUID(),
                contactIdentifier: "john@example.com",
                displayName: "John Doe",
                orbitId: UUID(),
                lastMessageAt: Date().addingTimeInterval(-86400 * 15),
                orbit: Orbit(
                    userId: UUID(),
                    name: "Near",
                    intervalDays: 14,
                    slackDays: 7,
                    position: 1
                )
            ),
            tags: [],
            onTap: {},
            onMessage: {},
            onRemoveOrbit: {},
            onSnooze: {}
        )
        .padding()
    }
}