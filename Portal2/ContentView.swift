import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        ZStack{
            ChatContainerView()
                .frame(minWidth: 100, minHeight: 140)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(Store())
}
