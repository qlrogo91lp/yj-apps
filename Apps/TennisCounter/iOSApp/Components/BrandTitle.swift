import SwiftUI

struct BrandTitle: View {
    var fontWeight: Font.Weight = .semibold

    var body: some View {
        VStack(spacing: 4) {
            Text("Ralli")
                .font(.system(size: 52, weight: .bold))
                .foregroundStyle(.green)
                .italic()
            Text("Tennis Counter")
                .font(.system(size: 18, weight: fontWeight))
                .foregroundColor(.white)
        }
    }
}

#Preview {
    BrandTitle()
}
