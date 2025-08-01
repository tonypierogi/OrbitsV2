import SwiftUI

struct OrbitsView: View {
    var body: some View {
        List {
            NavigationLink("Orbit Contact A (Tap Me)") {
                ContactDetailView()
            }
            NavigationLink("Orbit Contact B (Tap Me)") {
                ContactDetailView()
            }
        }
        .navigationTitle("Orbits")
    }
}