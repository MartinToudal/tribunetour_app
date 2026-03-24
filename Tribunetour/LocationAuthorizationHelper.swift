import Foundation
import CoreLocation

public func locationAuthorizationHint(_ status: CLAuthorizationStatus) -> String {
    switch status {
    case .notDetermined:
        return "Tryk “Tillad lokation” for at sortere efter afstand."
    case .denied, .restricted:
        return "Lokation er slået fra. Slå det til i Indstillinger → Privatliv & sikkerhed → Lokalitetstjenester."
    case .authorizedWhenInUse, .authorizedAlways:
        return "Vi venter på din position…"
    @unknown default:
        return "Ukendt lokationsstatus."
    }
}
