import SwiftUI
import OrbitsKit

struct TagChipView: View {
    let tag: Tag
    let category: TagCategory?
    
    var body: some View {
        Text(tag.label)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.15))
            .foregroundColor(.blue)
            .clipShape(Capsule())
    }
}

struct TagChipsView: View {
    let tags: [Tag]
    let categories: [TagCategory]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tags) { tag in
                    TagChipView(
                        tag: tag,
                        category: categories.first { $0.id == tag.categoryId }
                    )
                }
            }
        }
    }
}