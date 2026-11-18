import CoreLocation
import Foundation

@MainActor final class PhoneLocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var completion: ((Double, Double) -> Void)?
    override init() {
        super.init(); manager.delegate = self
    }

    func request(_ completion: @escaping (Double, Double) -> Void) {
        self.completion = completion
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways { manager.requestLocation() }
    }

    func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last { completion?(location.coordinate.latitude, location.coordinate.longitude) }
        completion = nil
    }

    func locationManager(_: CLLocationManager, didFailWithError _: Error) {
        completion = nil
    }
}
