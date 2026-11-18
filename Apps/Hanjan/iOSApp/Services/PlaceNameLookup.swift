import CoreLocation
import Foundation

/// 회고 폼의 장소 이름 자동 입력(역지오코딩). 실패하면 nil — 사용자가 직접 적으면 된다.
/// 시스템 API 래퍼라 원래 `Shared/Services/` 자리지만 T4 소유 폴더 밖이라 기능 안에 둔다 (T9 에서 옮길 수 있다).
enum PlaceNameLookup {
    static func name(latitude: Double, longitude: Double) async -> String? {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "ko_KR"))
        guard let placemark = placemarks?.first else { return nil }
        // "성수동" 처럼 동 이름이 가장 알아보기 쉽다. 없으면 구·시, 그래도 없으면 장소 이름.
        return [placemark.subLocality, placemark.locality, placemark.name]
            .compactMap(\.self)
            .first { !$0.isEmpty }
    }
}
