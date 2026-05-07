import SwiftUI

struct ExerciseMetric: View {
    let value: String
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 16))
            Text(value)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.white)
            Text(unit)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }
}
