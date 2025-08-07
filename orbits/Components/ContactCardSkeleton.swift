import SwiftUI

struct ContactCardSkeleton: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile placeholder
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 48, height: 48)
                .overlay(
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.clear, Color.white.opacity(0.5), Color.clear]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .offset(x: isAnimating ? 100 : -100)
                        .animation(
                            Animation.linear(duration: 1.5)
                                .repeatForever(autoreverses: false),
                            value: isAnimating
                        )
                )
                .clipped()
            
            VStack(alignment: .leading, spacing: 8) {
                // Name placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 150, height: 16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.clear, Color.white.opacity(0.5), Color.clear]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .offset(x: isAnimating ? 200 : -200)
                            .animation(
                                Animation.linear(duration: 1.5)
                                    .repeatForever(autoreverses: false),
                                value: isAnimating
                            )
                    )
                    .clipped()
                
                // Status placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 100, height: 12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.clear, Color.white.opacity(0.5), Color.clear]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .offset(x: isAnimating ? 200 : -200)
                            .animation(
                                Animation.linear(duration: 1.5)
                                    .repeatForever(autoreverses: false),
                                value: isAnimating
                            )
                    )
                    .clipped()
            }
            
            Spacer()
            
            // Button placeholders
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Circle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(16)
        .frame(minHeight: 80)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .onAppear {
            isAnimating = true
        }
    }
}

struct ContactCardSkeleton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            ContactCardSkeleton()
            ContactCardSkeleton()
            ContactCardSkeleton()
        }
        .padding()
    }
}