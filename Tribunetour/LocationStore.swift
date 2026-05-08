import Foundation
import CoreLocation
import Combine

final class LocationStore: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let minimumRequestInterval: TimeInterval = 15
    private let freshLocationInterval: TimeInterval = 120
    private var lastRequestAt: Date?
    private var requestInFlight = false

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
        guard authorization == .authorizedWhenInUse || authorization == .authorizedAlways else { return }
        guard !requestInFlight else { return }

        let now = Date()
        if let location, abs(location.timestamp.timeIntervalSinceNow) < freshLocationInterval {
            return
        }

        if let lastRequestAt, now.timeIntervalSince(lastRequestAt) < minimumRequestInterval {
            return
        }

        requestInFlight = true
        self.lastRequestAt = now
        manager.requestLocation()
    }

    func stop() {
        manager.stopUpdatingLocation()
        requestInFlight = false
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorization = manager.authorizationStatus
            if self.authorization == .authorizedWhenInUse || self.authorization == .authorizedAlways {
                if self.requestInFlight {
                    manager.requestLocation()
                }
            } else {
                self.location = nil
                self.requestInFlight = false
                manager.stopUpdatingLocation()
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        DispatchQueue.main.async {
            self.requestInFlight = false
            self.location = last
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.requestInFlight = false
        }
    }
}
