import Foundation
import CoreLocation

/// Vraagt toestemming voor je locatie en houdt bij waar je bent.
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var location: CLLocation?
    @Published var status: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 20
        status = manager.authorizationStatus
    }

    var isDenied: Bool { status == .denied || status == .restricted }

    func start() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else {
            manager.startUpdatingLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let newStatus = manager.authorizationStatus
        DispatchQueue.main.async { self.status = newStatus }
        if newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        DispatchQueue.main.async { self.location = latest }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Geen locatie: de kaart werkt gewoon verder zonder blauwe stip.
    }
}
