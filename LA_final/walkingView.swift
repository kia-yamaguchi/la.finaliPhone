import SwiftUI
import MapKit
import CoreLocation


struct WalkingView: View {

    @ObservedObject var location:
        WalkLocation

    let topic: String?

    let onStop: () -> Void


    // お題を達成したか
    @State private var topicCleared =
        false


    // #FFFCF3
    private let controlBackground =
        Color(
            red: 255 / 255,
            green: 252 / 255,
            blue: 243 / 255
        )


    var body: some View {

        ZStack {

            // 画面の最下部まで
            // 同じ色にする
            controlBackground
                .ignoresSafeArea()


            GeometryReader { geo in

                VStack(spacing: 0) {

                    // MARK: - MAP

                    ZStack {

                        LiveWalkMap(
                            coordinates:
                                location
                                    .locations
                                    .map(\.coordinate),

                            current:
                                location.current
                        )


                        // 位置情報メッセージ
                        if let message =
                            location.message {

                            VStack {

                                Spacer()


                                Text(message)
                                    .font(.caption)
                                    .foregroundStyle(
                                        .black
                                    )
                                    .padding(
                                        .horizontal,
                                        14
                                    )
                                    .padding(
                                        .vertical,
                                        8
                                    )
                                    .background(
                                        .regularMaterial,
                                        in:
                                            RoundedRectangle(
                                                cornerRadius: 8
                                            )
                                    )
                                    .padding(
                                        .bottom,
                                        16
                                    )
                            }
                        }
                    }
                    .frame(
                        width:
                            geo.size.width,

                        height:
                            geo.size.height
                            * 2 / 3
                    )
                    .clipped()


                    // MARK: - Control Area

                    ZStack {

                        controlBackground


                        VStack(spacing: 0) {

                            // MARK: お題 + CLEAR

                            HStack(spacing: 12) {

                                Text(
                                    topic
                                    ?? "お題なし"
                                )
                                .font(
                                    .system(
                                        size: 22
                                    )
                                )
                                .foregroundStyle(
                                    .black
                                )
                                .multilineTextAlignment(
                                    .center
                                )


                                // お題がある時だけ
                                // クリアボタンを表示
                                if topic != nil {

                                    Button {

                                        topicCleared
                                            .toggle()

                                    } label: {

                                        Circle()
                                            .fill(
                                                topicCleared
                                                ? AppTheme.coral
                                                : controlBackground
                                            )
                                            .frame(
                                                width: 24,
                                                height: 24
                                            )
                                            .overlay {

                                                Circle()
                                                    .stroke(
                                                        Color.black,
                                                        lineWidth: 2
                                                    )
                                            }
                                    }
                                    .buttonStyle(
                                        .plain
                                    )
                                    .accessibilityLabel(
                                        "お題クリア"
                                    )
                                    .accessibilityValue(
                                        topicCleared
                                        ? "達成"
                                        : "未達成"
                                    )
                                }
                            }
                            .frame(
                                maxWidth:
                                    .infinity,

                                alignment:
                                    .center
                            )

                            // 元より約1.25文字分下
                            .padding(
                                .top,
                                48
                            )


                            Spacer()


                            // MARK: STOP Button

                            Button {

                                onStop()

                            } label: {

                                RoundedRectangle(
                                    cornerRadius: 3
                                )
                                .fill(
                                    controlBackground
                                )
                                .frame(
                                    width: 42,
                                    height: 42
                                )
                            }
                            .buttonStyle(
                                StopButtonStyle(
                                    background:
                                        controlBackground
                                )
                            )
                            .accessibilityLabel(
                                "散歩を終了"
                            )


                            // MARK: STOP Text

                            Text("STOP")
                                .font(
                                    .system(
                                        size: 20
                                    )
                                )
                                .foregroundStyle(
                                    .black
                                )
                                .padding(
                                    .top,
                                    10
                                )


                            Spacer()
                        }
                    }
                    .frame(
                        width:
                            geo.size.width,

                        height:
                            geo.size.height
                            / 3
                    )
                }
            }
        }
    }
}


// MARK: - STOP Button Style

private struct StopButtonStyle:
    ButtonStyle {

    let background: Color


    func makeBody(
        configuration: Configuration
    ) -> some View {

        configuration.label

            .overlay {

                RoundedRectangle(
                    cornerRadius: 3
                )
                .stroke(
                    configuration.isPressed
                    ? AppTheme.coral
                    : Color.black,

                    lineWidth: 3
                )
            }
    }
}


// MARK: - Live Walk Map

struct LiveWalkMap:
    UIViewRepresentable {

    let coordinates:
        [CLLocationCoordinate2D]

    let current:
        CLLocationCoordinate2D?


    func makeUIView(
        context: Context
    ) -> MKMapView {

        let map =
            MKMapView(
                frame: .zero
            )


        map.mapType =
            .standard


        map.delegate =
            context.coordinator


        // 標準の青い現在地は非表示
        map.showsUserLocation =
            false


        map.isZoomEnabled =
            true

        map.isScrollEnabled =
            true

        map.isRotateEnabled =
            false

        map.isPitchEnabled =
            false


        return map
    }


    func updateUIView(
        _ map: MKMapView,
        context: Context
    ) {

        updateRoute(
            map,
            context:
                context
        )


        guard
            let current
        else {
            return
        }


        updateCurrentMarker(
            map,
            coordinate:
                current,
            context:
                context
        )


        moveMapToCurrentLocation(
            map,
            coordinate:
                current,
            context:
                context
        )
    }


    // MARK: - Route

    private func updateRoute(
        _ map: MKMapView,
        context: Context
    ) {

        guard
            context
                .coordinator
                .coordinateCount
            != coordinates.count
        else {
            return
        }


        map.removeOverlays(
            map.overlays
        )


        if coordinates.count >= 2 {

            let polyline =
                MKPolyline(
                    coordinates:
                        coordinates,

                    count:
                        coordinates.count
                )


            map.addOverlay(
                polyline
            )
        }


        context
            .coordinator
            .coordinateCount =
            coordinates.count
    }


    // MARK: - Current Marker

    private func updateCurrentMarker(
        _ map: MKMapView,
        coordinate:
            CLLocationCoordinate2D,
        context: Context
    ) {

        if let annotation =
            context
                .coordinator
                .currentAnnotation {

            annotation.coordinate =
                coordinate

        } else {

            let annotation =
                CurrentLocationAnnotation(
                    coordinate:
                        coordinate
                )


            context
                .coordinator
                .currentAnnotation =
                annotation


            map.addAnnotation(
                annotation
            )
        }
    }


    // MARK: - Follow Current Location

    private func moveMapToCurrentLocation(
        _ map: MKMapView,
        coordinate:
            CLLocationCoordinate2D,
        context: Context
    ) {

        let coordinator =
            context.coordinator


        // 初回
        if !coordinator.hasCentered {

            let region =
                MKCoordinateRegion(
                    center:
                        coordinate,

                    latitudinalMeters:
                        400,

                    longitudinalMeters:
                        400
                )


            map.setRegion(
                region,
                animated: false
            )


            coordinator
                .hasCentered =
                true


            coordinator
                .lastCoordinate =
                coordinate


            return
        }


        // 2回目以降
        if let last =
            coordinator.lastCoordinate {

            let oldLocation =
                CLLocation(
                    latitude:
                        last.latitude,

                    longitude:
                        last.longitude
                )


            let newLocation =
                CLLocation(
                    latitude:
                        coordinate.latitude,

                    longitude:
                        coordinate.longitude
                )


            let moved =
                newLocation.distance(
                    from:
                        oldLocation
                )


            if moved >= 2 {

                map.setCenter(
                    coordinate,
                    animated: true
                )


                coordinator
                    .lastCoordinate =
                    coordinate
            }

        } else {

            coordinator
                .lastCoordinate =
                coordinate
        }
    }


    // MARK: - Coordinator

    func makeCoordinator()
        -> Coordinator {

        Coordinator()
    }


    final class Coordinator:
        NSObject,
        MKMapViewDelegate {

        var coordinateCount =
            -1


        var hasCentered =
            false


        var lastCoordinate:
            CLLocationCoordinate2D?


        var currentAnnotation:
            CurrentLocationAnnotation?


        // MARK: Route Line

        func mapView(
            _ mapView: MKMapView,
            rendererFor overlay:
                MKOverlay
        ) -> MKOverlayRenderer {

            guard
                let polyline =
                    overlay
                    as? MKPolyline
            else {

                return
                    MKOverlayRenderer(
                        overlay:
                            overlay
                    )
            }


            let renderer =
                MKPolylineRenderer(
                    polyline:
                        polyline
                )


            renderer.strokeColor =
                .black


            renderer.lineWidth =
                4


            renderer.lineCap =
                .round


            renderer.lineJoin =
                .round


            return renderer
        }


        // MARK: Current Marker

        func mapView(
            _ mapView: MKMapView,
            viewFor annotation:
                MKAnnotation
        ) -> MKAnnotationView? {

            guard
                annotation
                is CurrentLocationAnnotation
            else {
                return nil
            }


            let identifier =
                "CurrentLocationMarker"


            let view:
                CurrentLocationMarkerView


            if let reused =
                mapView
                    .dequeueReusableAnnotationView(
                        withIdentifier:
                            identifier
                    )
                    as?
                    CurrentLocationMarkerView {

                view =
                    reused

                view.annotation =
                    annotation

            } else {

                view =
                    CurrentLocationMarkerView(
                        annotation:
                            annotation,

                        reuseIdentifier:
                            identifier
                    )
            }


            return view
        }
    }
}


// MARK: - Current Location Annotation

final class CurrentLocationAnnotation:
    NSObject,
    MKAnnotation {

    @objc dynamic
    var coordinate:
        CLLocationCoordinate2D


    init(
        coordinate:
            CLLocationCoordinate2D
    ) {

        self.coordinate =
            coordinate

        super.init()
    }
}


// MARK: - Pink Tear Marker

final class CurrentLocationMarkerView:
    MKAnnotationView {


    override init(
        annotation:
            MKAnnotation?,
        reuseIdentifier:
            String?
    ) {

        super.init(
            annotation:
                annotation,

            reuseIdentifier:
                reuseIdentifier
        )


        setup()
    }


    required init?(
        coder: NSCoder
    ) {

        super.init(
            coder:
                coder
        )


        setup()
    }


    private func setup() {

        frame =
            CGRect(
                x: 0,
                y: 0,
                width: 34,
                height: 44
            )


        backgroundColor =
            .clear


        centerOffset =
            CGPoint(
                x: 0,
                y: -22
            )


        isOpaque =
            false


        canShowCallout =
            false
    }


    override func draw(
        _ rect: CGRect
    ) {

        let width =
            rect.width

        let height =
            rect.height


        let path =
            UIBezierPath()


        // 下の尖った先端
        path.move(
            to:
                CGPoint(
                    x:
                        width / 2,

                    y:
                        height - 1
                )
        )


        // 左側
        path.addCurve(

            to:
                CGPoint(
                    x: 2,

                    y:
                        height
                        * 0.38
                ),

            controlPoint1:
                CGPoint(
                    x:
                        width
                        * 0.30,

                    y:
                        height
                        * 0.78
                ),

            controlPoint2:
                CGPoint(
                    x: 2,

                    y:
                        height
                        * 0.60
                )
        )


        // 左上
        path.addCurve(

            to:
                CGPoint(
                    x:
                        width / 2,

                    y: 1
                ),

            controlPoint1:
                CGPoint(
                    x: 2,

                    y:
                        height
                        * 0.13
                ),

            controlPoint2:
                CGPoint(
                    x:
                        width
                        * 0.23,

                    y: 1
                )
        )


        // 右上
        path.addCurve(

            to:
                CGPoint(
                    x:
                        width - 2,

                    y:
                        height
                        * 0.38
                ),

            controlPoint1:
                CGPoint(
                    x:
                        width
                        * 0.77,

                    y: 1
                ),

            controlPoint2:
                CGPoint(
                    x:
                        width - 2,

                    y:
                        height
                        * 0.13
                )
        )


        // 右側から先端へ
        path.addCurve(

            to:
                CGPoint(
                    x:
                        width / 2,

                    y:
                        height - 1
                ),

            controlPoint1:
                CGPoint(
                    x:
                        width - 2,

                    y:
                        height
                        * 0.60
                ),

            controlPoint2:
                CGPoint(
                    x:
                        width
                        * 0.70,

                    y:
                        height
                        * 0.78
                )
        )


        path.close()


        UIColor(
            red:
                254 / 255,

            green:
                114 / 255,

            blue:
                114 / 255,

            alpha: 1
        )
        .setFill()


        path.fill()
    }
}
