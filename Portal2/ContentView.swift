import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        ChatContainerView()
        .frame(minWidth: 200, minHeight: 140)
    }
}

#Preview {
    ContentView()
        .environmentObject(Store())
}
