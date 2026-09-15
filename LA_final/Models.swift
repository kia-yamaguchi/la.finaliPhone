import SwiftUI
import MapKit
import CoreLocation
import Combine


// MARK: - Color

enum AppTheme {

    static let paper = Color(
        red: 0.98,
        green: 0.96,
        blue: 0.89
    )

    static let coral = Color(
        red: 254 / 255,
        green: 114 / 255,
        blue: 114 / 255
    )

    static let lightPink = Color(
        red: 254 / 255,
        green: 184 / 255,
        blue: 184 / 255
    )

    static let palette: [Color] = [
        .red,
        .orange,
        .yellow,
        .green,
        .blue,
        .purple,
        .brown,
        .black
    ]
}


// MARK: - InkStroke

struct InkStroke: Codable {

    var points: [CGPoint]

    var color: Int

    var width: CGFloat = 3
}


// MARK: - WalkCard

struct WalkCard: Identifiable, Codable {

    var id = UUID()

    var name: String

    var route: [CGPoint]

    var strokes: [InkStroke]

    var date: Date

    var distance: Double

    var duration: TimeInterval

    var topic: String?
}


// MARK: - WalkStage

enum WalkStage {

    case setup

    case walking

    case drawing

    case naming
}


// MARK: - WalkLocation

final class WalkLocation:
    NSObject,
    ObservableObject,
    CLLocationManagerDelegate {

    // MARK: Published

    @Published var locations: [CLLocation] = []

    @Published var current: CLLocationCoordinate2D?

    @Published var message: String?


    // MARK: Location Manager

    private let manager = CLLocationManager()

    private var recording = false


    // MARK: Init

    override init() {

        super.init()

        manager.delegate = self

        manager.desiredAccuracy =
            kCLLocationAccuracyBest

        manager.distanceFilter = 2

        manager.activityType = .fitness

        manager.pausesLocationUpdatesAutomatically =
            false
    }


    // MARK: - Start

    func start() {

        locations = []

        current = nil

        message =
            "現在地を取得しています..."

        recording = true


        // 位置情報サービスそのものがOFF
        guard CLLocationManager
            .locationServicesEnabled()
        else {

            message =
                "位置情報サービスがオフになっています。"

            return
        }


        switch manager.authorizationStatus {

        case .notDetermined:

            manager
                .requestWhenInUseAuthorization()


        case .authorizedAlways,
             .authorizedWhenInUse:

            startLocationUpdates()


        case .denied,
             .restricted:

            message =
                "位置情報を利用できません。設定から位置情報を許可してください。"


        @unknown default:

            message =
                "位置情報を利用できません。"
        }
    }


    // MARK: - Stop

    func stop() {

        recording = false

        manager.stopUpdatingLocation()
    }


    // MARK: - Start Updates

    private func startLocationUpdates() {

        guard recording else {
            return
        }


        message =
            "現在地を取得しています..."


        // すでに位置が取得済みなら
        // 先に現在地として利用する
        if let location = manager.location {

            current =
                location.coordinate


            if locations.isEmpty {

                locations.append(
                    location
                )
            }
        }


        manager.startUpdatingLocation()
    }


    // MARK: - Authorization Changed

    func locationManagerDidChangeAuthorization(
        _ manager: CLLocationManager
    ) {

        guard recording else {
            return
        }


        switch manager.authorizationStatus {

        case .authorizedAlways,
             .authorizedWhenInUse:

            startLocationUpdates()


        case .denied,
             .restricted:

            message =
                "位置情報を利用できません。設定から位置情報を許可してください。"


        case .notDetermined:

            break


        @unknown default:

            break
        }
    }


    // MARK: - Location Updated

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations updates: [CLLocation]
    ) {

        guard recording else {
            return
        }


        guard !updates.isEmpty else {
            return
        }


        for location in updates {

            // 無効な位置情報だけ除外
            guard
                location.horizontalAccuracy >= 0
            else {
                continue
            }


            // ★重要
            // 以前の <= 50m 制限を削除
            // シミュレータでも現在地を受け取れるようにする

            current =
                location.coordinate

            message = nil


            // 同じ、または古いデータは追加しない
            if let last = locations.last {

                if location.timestamp
                    <= last.timestamp {

                    continue
                }
            }


            locations.append(
                location
            )
        }
    }


    // MARK: - Error

    func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {

        if let clError =
            error as? CLError {

            switch clError.code {

            case .locationUnknown:

                message =
                    "現在地を取得しています..."

            case .denied:

                message =
                    "位置情報の利用が許可されていません。"

            default:

                message =
                    "現在地を取得できませんでした。"
            }

        } else {

            message =
                "現在地を取得できませんでした。"
        }
    }


    // MARK: - Distance

    var distance: Double {

        guard locations.count >= 2 else {
            return 0
        }


        return zip(
            locations,
            locations.dropFirst()
        )
        .reduce(0) {

            $0
            + $1.0.distance(
                from: $1.1
            )
        }
    }


    // MARK: - Normalized Route

    var normalizedRoute: [CGPoint] {

        let points =
            locations.map {

                MKMapPoint(
                    $0.coordinate
                )
            }


        guard
            let first = points.first
        else {
            return []
        }


        let minX =
            points.map(\.x).min()
            ?? first.x

        let maxX =
            points.map(\.x).max()
            ?? first.x

        let minY =
            points.map(\.y).min()
            ?? first.y

        let maxY =
            points.map(\.y).max()
            ?? first.y


        let scale =
            max(
                maxX - minX,
                maxY - minY,
                1
            )


        return points.map { point in

            CGPoint(

                x:
                    0.5
                    + (
                        point.x
                        - (minX + maxX) / 2
                    )
                    / scale
                    * 0.8,

                y:
                    0.5
                    + (
                        point.y
                        - (minY + maxY) / 2
                    )
                    / scale
                    * 0.8
            )
        }
    }
}
