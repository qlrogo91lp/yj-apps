import MapKit
import SwiftUI

/// 상세 맨 위의 작은 지도. 좌표가 없으면 호출부가 이 뷰 자체를 그리지 않는다.
struct SessionMap: View {
    let latitude: Double
    let longitude: Double
    let placeName: String?

    private var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var body: some View {
        Map(
            initialPosition: .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 600, longitudinalMeters: 600)),
            interactionModes: []
        ) {
            Marker(placeName ?? "술자리", coordinate: coordinate)
                .tint(BrandColor.amber)
        }
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    SessionMap(latitude: 37.5445, longitude: 127.0557, placeName: "성수동")
        .padding()
        .background(BrandColor.background)
        .preferredColorScheme(.dark)
}
