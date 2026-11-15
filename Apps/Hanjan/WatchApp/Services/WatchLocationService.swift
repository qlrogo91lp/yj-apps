import CoreLocation

@MainActor final class WatchLocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var completion: ((Double, Double) -> Void)?
    override init() {
        super.init(); manager.delegate = self
    }

    func request(_ completion: @escaping (Double, Double) -> Void) {
        self.completion = completion
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        default: self.completion = nil
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse { manager.requestLocation() }
        }
    }

    nonisolated func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        Task { @MainActor in completion?(coordinate.latitude, coordinate.longitude); completion = nil }
    }

    nonisolated func locationManager(_: CLLocationManager, didFailWithError _: Error) {
        Task { @MainActor in completion = nil }
    }
}
