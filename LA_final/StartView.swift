import SwiftUI
import MapKit
import CoreLocation
import Combine

private let paper = Color(red: 0.98, green: 0.96, blue: 0.89)
private let coral = Color(red: 254/255, green: 114/255, blue: 114/255)
private let lightPink = Color(red: 254/255, green: 184/255, blue: 184/255)
private let palette: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .brown, .black]

struct InkStroke: Codable { var points: [CGPoint]; var color: Int }
extension InkStroke {
    // Test segments as well as samples so fast pen movements remain erasable.
    func touches(_ point: CGPoint, in size: CGSize, radius: Double) -> Bool {
        func pixel(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x*size.width, y: p.y*size.height) }
        let target = pixel(point)
        guard let first = points.first else { return false }
        if hypot(pixel(first).x-target.x, pixel(first).y-target.y) <= radius { return true }
        return zip(points, points.dropFirst()).contains { start, end in
            let a = pixel(start), b = pixel(end)
            let dx = b.x-a.x, dy = b.y-a.y
            let length = dx*dx+dy*dy
            let t = length == 0 ? 0 : min(1, max(0, ((target.x-a.x)*dx+(target.y-a.y)*dy)/length))
            return hypot(target.x-a.x-t*dx, target.y-a.y-t*dy) <= radius
        }
    }
}
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
enum WalkStage { case setup, walking, drawing, naming }

final class WalkLocation: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var locations: [CLLocation] = []
    @Published var current: CLLocationCoordinate2D?
    @Published var message: String?
    private let manager = CLLocationManager()
    private var recording = false
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 3
        manager.activityType = .fitness
    }
    func start() {
        locations = []; message = nil; recording = true
        if manager.authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
        else { updateAuthorization() }
    }
    func stop() { recording = false; manager.stopUpdatingLocation() }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) { updateAuthorization() }
    private func updateAuthorization() {
        guard recording else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: message = nil; manager.startUpdatingLocation()
        case .denied, .restricted: message = "位置情報を利用できません。設定で位置情報を許可してください。"
        default: break
        }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations updates: [CLLocation]) {
        guard recording else { return }
        for location in updates where location.horizontalAccuracy >= 0 && location.horizontalAccuracy <= 50 && abs(location.timestamp.timeIntervalSinceNow) < 15 {
            current = location.coordinate; message = nil
            if let last = locations.last, location.timestamp <= last.timestamp { continue }
            locations.append(location)
        }
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        message = "現在地を取得できません。位置情報を確認してください。"
    }
    var distance: Double { zip(locations, locations.dropFirst()).reduce(0) { $0 + $1.0.distance(from: $1.1) } }
    var normalizedRoute: [CGPoint] {
        let points = locations.map { MKMapPoint($0.coordinate) }
        guard let first = points.first else { return [] }
        let minX = points.map(\.x).min() ?? first.x, maxX = points.map(\.x).max() ?? first.x
        let minY = points.map(\.y).min() ?? first.y, maxY = points.map(\.y).max() ?? first.y
        let scale = max(maxX-minX, maxY-minY, 1)
        return points.map { CGPoint(x: 0.5 + ($0.x-(minX+maxX)/2)/scale*0.8, y: 0.5 + ($0.y-(minY+maxY)/2)/scale*0.8) }
    }
}

struct ContentView: View {
    @StateObject private var location = WalkLocation()
    @State private var tab = 0
    @State private var stage: WalkStage = .setup
    @State private var topics = ["公園を通ろう", "右折を3回しよう", "赤いものを見つけよう", "ピンク色の靴の人を見つけよう"]
    @State private var candidates: [String] = []
    @State private var topic: String?
    @State private var rotation = 0.0
    @State private var spinning = false
    @State private var showAdd = false
    @State private var newTopic = ""
    @FocusState private var topicFocus: Bool
    @State private var cards: [WalkCard] = []
    @State private var name = ""
    @State private var ink = 7
    @State private var erasing = false
    @State private var strokes: [InkStroke] = []
    @State private var current: InkStroke?
    @State private var undoHistory: [[InkStroke]] = []
    @State private var redoHistory: [[InkStroke]] = []
    @State private var eraseStarted = false
    @State private var startedAt = Date()
    @State private var duration: TimeInterval = 0
    @State private var saveError = false
    @State private var selectedCard: WalkCard?
    @State private var topicAchieved = false

    var body: some View {
        TabView(selection: $tab) {
            ZStack { paper.ignoresSafeArea(); walkView }
                .tabItem { Label("散歩", systemImage: "figure.walk") }.tag(0)
            NavigationStack { bookView }
                .tabItem { Label("図鑑", systemImage: "book.closed") }.tag(1)
        }
        .tint(coral).preferredColorScheme(.light)
        .toolbar(stage == .setup ? .visible : .hidden, for: .tabBar)
        .sheet(isPresented: $showAdd) { addTopicView }
        .sheet(item: $selectedCard) { card in detailSheet(card) }
        .alert("作品を保存できませんでした", isPresented: $saveError) { Button("OK", role: .cancel) {} }
        .onAppear {
            if let savedTopics = UserDefaults.standard.stringArray(forKey: "walkingTopics"), savedTopics.count >= 4 { topics = savedTopics }
            if candidates.isEmpty { candidates = Array(topics.shuffled().prefix(4)) }
            if let data = try? Data(contentsOf: Self.cardsURL), let saved = try? JSONDecoder().decode([WalkCard].self, from: data) { cards = saved }
        }
    }
    @ViewBuilder private var walkView: some View {
        switch stage {
        case .setup: setupView
        case .walking: walkingView
        case .drawing: drawingView
        case .naming: namingView
        }
    }
    private var setupView: some View {
        VStack(spacing: 30) {
            HStack { Button { showAdd = true } label: { Image(systemName: "plus").font(.system(size: 30)).foregroundStyle(.black).frame(width: 48, height: 48) }.disabled(spinning).accessibilityLabel("お題を追加"); Spacer() }
            Spacer()
            ZStack {
                ZStack {
                    ForEach(candidates.indices, id: \.self) { index in
                        WheelSlice(index: index).fill(index.isMultiple(of: 2) ? coral : lightPink)
                        Text(candidates[index]).font(.system(size: 13)).multilineTextAlignment(.center)
                            .frame(width: 83, height: 65)
                            .rotationEffect(.degrees(Double(index) * 90))
                            .offset(x: cos(Double(index)*Double.pi/2-Double.pi/2)*82, y: sin(Double(index)*Double.pi/2-Double.pi/2)*82)
                    }
                }.frame(width: 280, height: 280).rotationEffect(.degrees(rotation))
                Button(action: spin) { Text("GO").font(.headline).foregroundStyle(.black).frame(width: 50, height: 50).background(.white, in: Circle()) }.disabled(spinning)
                Image(systemName: "arrowtriangle.down.fill").font(.system(size: 22)).foregroundStyle(.black).offset(y: -145).allowsHitTesting(false)
            }.frame(height: 300)
            Button {
                startedAt = Date(); location.start(); stage = .walking
            } label: {
                VStack { Image(systemName: "play").font(.system(size: 34)); Text("START") }.foregroundStyle(.black).frame(width: 110, height: 75).contentShape(Rectangle())
            }.disabled(spinning)
            Spacer()
        }.padding(.horizontal, 20)
    }
    private func spin() {
        guard !spinning, candidates.count == 4 else { return }
        spinning = true
        let index = Int.random(in: 0..<4)
        let target = Double((4-index)%4)*90
        withAnimation(.easeOut(duration: 2)) { rotation = (floor(rotation/360)+4)*360+target }
        DispatchQueue.main.asyncAfter(deadline: .now()+2) { topic = candidates[index]; spinning = false }
    }
    private var walkingView: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                LiveWalkMap(coordinates: location.locations.map(\.coordinate), current: location.current).ignoresSafeArea()
                VStack { HStack { Text(topic ?? "お題なし").padding(10).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8)); if topic != nil { Button { topicAchieved.toggle() } label: { Image(systemName: topicAchieved ? "checkmark.circle.fill" : "circle").foregroundStyle(.black).font(.title2) }.accessibilityLabel("お題達成") } }
                    if let message = location.message { Text(message).font(.caption).padding(8).background(.regularMaterial) }
                }.padding()
                Button {
                    location.stop(); duration = Date().timeIntervalSince(startedAt); stage = .drawing
                } label: {
                    Image(systemName: "stop.fill").font(.system(size: 28, weight: .medium)).foregroundStyle(.black).frame(width: 62, height: 62).background(coral, in: Circle())
                }.accessibilityLabel("散歩を終了").position(x: geo.size.width/2, y: geo.size.height*2/3)
            }
        }
    }
    private var drawingView: some View {
        VStack(spacing: 12) {
            HStack {
                Button { redoHistory.append(strokes); strokes = undoHistory.removeLast() } label: { Image(systemName: "arrow.uturn.backward") }.disabled(undoHistory.isEmpty).accessibilityLabel("戻る")
                Button { undoHistory.append(strokes); strokes = redoHistory.removeLast() } label: { Image(systemName: "arrow.uturn.forward") }.disabled(redoHistory.isEmpty).accessibilityLabel("進む")
                Spacer(); doneButton { stage = .naming }
            }.font(.title2).foregroundStyle(.black)
            ScrollView([.horizontal, .vertical], showsIndicators: false) { GeometryReader { geo in
                Artwork(route: location.normalizedRoute, strokes: strokes + (current.map { [$0] } ?? []))
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                        let point = CGPoint(x: min(1,max(0,value.location.x/geo.size.width)), y: min(1,max(0,value.location.y/geo.size.height)))
                        if erasing {
                            if !eraseStarted { undoHistory.append(strokes); redoHistory = []; eraseStarted = true }
                            strokes = erase(point: point, from: strokes, in: geo.size)
                        } else {
                            if current == nil { current = InkStroke(points: [], color: ink) }
                            current?.points.append(point)
                        }
                    }.onEnded { _ in
                        if let current { undoHistory.append(strokes); redoHistory = []; strokes.append(current) }
                        current = nil; eraseStarted = false
                    })
            }.frame(width: 540, height: 540) }.frame(maxHeight: 560)
            HStack(spacing: 22) {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(36)), count: 4), spacing: 12) {
                    ForEach(palette.indices, id: \.self) { index in
                        Button { ink = index; erasing = false } label: { Circle().fill(palette[index]).frame(width: 28, height: 28).padding(3).overlay(Circle().stroke(ink == index && !erasing ? .black : .clear, lineWidth: 2)) }.accessibilityLabel(["赤", "オレンジ", "黄", "緑", "青", "紫", "茶", "黒"][index])
                    }
                }.frame(width: 168)
                Button { erasing.toggle() } label: { Image(systemName: "eraser").font(.title).foregroundStyle(erasing ? coral : .black).padding(8) }.accessibilityLabel("線を消す")
            }
            Spacer(minLength: 0)
        }.padding(20)
    }
    private var namingView: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack { Spacer(); doneButton(action: saveCard) }
                TextField("名前", text: $name).textFieldStyle(.roundedBorder)
                Artwork(route: location.normalizedRoute, strokes: strokes).aspectRatio(1, contentMode: .fit)
                metadata(topic: topic, date: startedAt, distance: location.distance, duration: duration)
            }.padding(20)
        }
    }
    private func doneButton(action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: "checkmark").font(.title2).foregroundStyle(.black).frame(width: 44, height: 44).background(coral, in: Circle()) }.accessibilityLabel("完了")
    }
    private func erase(point: CGPoint, from source: [InkStroke], in size: CGSize) -> [InkStroke] {
        var result: [InkStroke] = []
        for stroke in source {
            var segment: [CGPoint] = []
            for p in stroke.points {
                let pixel = CGPoint(x: p.x * size.width, y: p.y * size.height)
                if hypot(pixel.x - point.x * size.width, pixel.y - point.y * size.height) <= 20 {
                    if segment.count > 1 { result.append(InkStroke(points: segment, color: stroke.color)) }
                    segment = []
                } else {
                    segment.append(p)
                }
            }
            if segment.count > 1 { result.append(InkStroke(points: segment, color: stroke.color)) }
        }
        return result
    }
    private var bookView: some View {
        ScrollView {
            if cards.isEmpty { Text("作品を保存すると、ここに並びます").padding(.top, 80) }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 20) {
                ForEach(cards) { card in
                    Button {
                        selectedCard = card
                    } label: {
                        VStack { Artwork(route: card.route, strokes: card.strokes).aspectRatio(1, contentMode: .fit); Text(card.name).font(.caption).foregroundStyle(.black) }
                    }
                }
            }.padding(20)
        }.background(paper).navigationTitle("図鑑")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Text(badgeSymbol).font(.title2).accessibilityLabel("バッジ") } }
    }
    private var badgeSymbol: String { cards.count >= 10 ? "🏆" : cards.count >= 5 ? "🥇" : cards.count >= 1 ? "🏅" : "○" }
    private func detailSheet(_ card: WalkCard) -> some View {
        NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 16) { Text(card.name).font(.title2); Artwork(route: card.route, strokes: card.strokes).aspectRatio(1, contentMode: .fit); metadata(topic: card.topic, date: card.date, distance: card.distance, duration: card.duration) }.padding(20) }.background(paper).navigationTitle("作品詳細").navigationBarTitleDisplayMode(.inline) }
            .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
    }
    private func metadata(topic: String?, date: Date, distance: Double, duration: TimeInterval) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("お題：\(topic ?? "お題なし")")
            Text("日付：\(date.formatted(date: .numeric, time: .omitted))")
            Text(String(format: "歩行距離：%.2f km", distance/1000))
            Text("歩行時間：\(Int(duration)/60)分\(Int(duration)%60)秒")
        }.font(.subheadline).frame(maxWidth: .infinity, alignment: .leading).padding().background(Color.gray.opacity(0.2))
    }
    private var addTopicView: some View {
        VStack(spacing: 20) {
            Text("お題を追加")
            TextField("お題を入力", text: $newTopic).textFieldStyle(.roundedBorder).focused($topicFocus)
            Button("追加") {
                topics.append(newTopic.trimmingCharacters(in: .whitespacesAndNewlines)); UserDefaults.standard.set(topics, forKey: "walkingTopics"); candidates = Array(topics.shuffled().prefix(4)); topic = nil; rotation = 0; newTopic = ""; showAdd = false
            }.disabled(newTopic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }.padding(24).presentationDetents([.medium]).onAppear { topicFocus = true }
    }
    private static var cardsURL: URL { URL.documentsDirectory.appending(path: "walk-cards.json") }
    private func saveCard() {
        let card = WalkCard(name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "無題" : name, route: location.normalizedRoute, strokes: strokes, date: startedAt, distance: location.distance, duration: duration, topic: topic)
        do { try JSONEncoder().encode(cards + [card]).write(to: Self.cardsURL, options: .atomic) }
        catch { saveError = true; return }
        cards.append(card); name = ""; strokes = []; undoHistory = []; redoHistory = []; topic = nil
        candidates = Array(topics.shuffled().prefix(4)); rotation = 0; stage = .setup; tab = 1
    }
}

struct WheelSlice: Shape {
    let index: Int
    func path(in rect: CGRect) -> Path {
        var path = Path(); let center = CGPoint(x: rect.midX, y: rect.midY)
        path.move(to: center)
        path.addArc(center: center, radius: rect.width/2, startAngle: .degrees(Double(index)*90-135), endAngle: .degrees(Double(index)*90-45), clockwise: false)
        path.closeSubpath(); return path
    }
}

struct Artwork: View {
    let route: [CGPoint]
    let strokes: [InkStroke]
    var body: some View {
        Canvas { context, size in
            func draw(_ points: [CGPoint], color: Color) {
                guard let first = points.first else { return }
                let start = CGPoint(x: first.x*size.width, y: first.y*size.height)
                if points.count == 1 { context.fill(Path(ellipseIn: CGRect(x: start.x-2, y: start.y-2, width: 4, height: 4)), with: .color(color)); return }
                var path = Path(); path.move(to: start)
                for point in points.dropFirst() { path.addLine(to: CGPoint(x: point.x*size.width, y: point.y*size.height)) }
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            }
            draw(route, color: .black)
            for stroke in strokes { draw(stroke.points, color: palette[min(max(stroke.color, 0), 7)]) }
        }.background(.white).clipped()
    }
}

struct LiveWalkMap: UIViewRepresentable {
    let coordinates: [CLLocationCoordinate2D]
    let current: CLLocationCoordinate2D?
    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(); map.mapType = .standard; map.delegate = context.coordinator; return map
    }
    func updateUIView(_ map: MKMapView, context: Context) {
        if coordinates.count != context.coordinator.count {
            map.removeOverlays(map.overlays)
            if coordinates.count > 1 { map.addOverlay(MKPolyline(coordinates: coordinates, count: coordinates.count)) }
            context.coordinator.count = coordinates.count
        }
        if let current, context.coordinator.last?.latitude != current.latitude || context.coordinator.last?.longitude != current.longitude {
            map.removeAnnotations(map.annotations)
            let pin = MKPointAnnotation(); pin.coordinate = current; pin.title = "現在地"; map.addAnnotation(pin)
            map.setRegion(MKCoordinateRegion(center: current, latitudinalMeters: 700, longitudinalMeters: 700), animated: context.coordinator.last != nil)
            context.coordinator.last = current
        }
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    class Coordinator: NSObject, MKMapViewDelegate {
        var count = -1
        var last: CLLocationCoordinate2D?
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            let renderer = MKPolylineRenderer(overlay: overlay); renderer.strokeColor = .black; renderer.lineWidth = 4; return renderer
        }
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let pin = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "current")
            pin.markerTintColor = UIColor(red: 254/255, green: 114/255, blue: 114/255, alpha: 1); return pin
        }
    }
}

