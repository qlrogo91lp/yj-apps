import SwiftUI

struct StartView: View {
    let onStart: () -> Void
    var body: some View {
        VStack(spacing: 18) {
            Text("한잔").font(.title2.bold())
            Button("시작", action: onStart).buttonStyle(.borderedProminent).tint(BrandColor.amber).foregroundStyle(.black)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview { StartView(onStart: {}) }
