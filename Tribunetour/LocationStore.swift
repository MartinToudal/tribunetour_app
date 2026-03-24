import Foundation
import CoreLocation
import Combine

final class LocationStore: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    // Gør den robust på tværs af Xcode/SwiftUI quirks
    let objectWillChange = ObservableObjectPublisher()

    private(set) var authorization: CLAuthorizationStatus {
        didSet { objectWillChange.send() }
    }

    private(set) var location: CLLocation? {
        didSet { objectWillChange.send() }
    }

    override init() {
        self.authorization = manager.authorizationStatus
        self.location = nil
        super.init()

        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func start() {
        if authorization == .authorizedWhenInUse || authorization == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorization = manager.authorizationStatus
            if self.authorization == .authorizedWhenInUse || self.authorization == .authorizedAlways {
                manager.startUpdatingLocation()
            } else {
                self.location = nil
                manager.stopUpdatingLocation()
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        DispatchQueue.main.async {
            self.location = last
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Ignorer stille – UI håndterer bare at location er nil
    }
}
