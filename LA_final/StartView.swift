import SwiftUI

struct ContentView: View {

    @StateObject private var location =
        WalkLocation()

    @State private var tab = 0

    @State private var stage:
        WalkStage = .setup


    // MARK: Topic

    @State private var topics = [
        "公園を通ろう",
        "右折を3回しよう",
        "赤いものを見つけよう",
        "ピンク色の靴の人を見つけよう"
    ]

    @State private var candidates:
        [String] = []

    @State private var topic:
        String?

    @State private var rotation = 0.0

    @State private var spinning = false

    @State private var topicAchieved =
        false


    // MARK: Drawing

    @State private var strokes:
        [InkStroke] = []

    @State private var ink = 7

    @State private var erasing = false

    @State private var undoHistory:
        [[InkStroke]] = []

    @State private var redoHistory:
        [[InkStroke]] = []


    // MARK: Walk

    @State private var startedAt =
        Date()

    @State private var duration:
        TimeInterval = 0


    // MARK: Card

    @State private var cards:
        [WalkCard] = []

    @State private var name = ""

    @State private var saveError = false


    var body: some View {

        TabView(selection: $tab) {

            // MARK: Walk Tab

            ZStack {

                AppTheme.paper
                    .ignoresSafeArea()

                walkView
            }
            .tabItem {

                Label(
                    "散歩",
                    systemImage: "figure.walk"
                )
            }
            .tag(0)


            // MARK: Book Tab

            BookView(cards: cards)

                .tabItem {

                    Label(
                        "図鑑",
                        systemImage: "book.closed"
                    )
                }
                .tag(1)
        }

        .tint(AppTheme.coral)

        .preferredColorScheme(.light)

        .toolbar(
            stage == .setup
                ? .visible
                : .hidden,
            for: .tabBar
        )

        .alert(
            "作品を保存できませんでした",
            isPresented: $saveError
        ) {

            Button(
                "OK",
                role: .cancel
            ) {}
        }

        .onAppear {
            loadData()
        }
    }


    // MARK: - Screen Switch

    @ViewBuilder
    private var walkView: some View {

        switch stage {

        case .setup:

            SetupView(
                topics: $topics,
                candidates: $candidates,
                topic: $topic,
                rotation: $rotation,
                spinning: $spinning
            ) {

                startWalking()
            }


        case .walking:

            WalkingView(
                location: location,
                topic: topic,
            ) {
                stopWalking()
            }


        case .drawing:

            DrawingView(
                route:
                    location.normalizedRoute,
                strokes:
                    $strokes,
                ink:
                    $ink,
                erasing:
                    $erasing,
                undoHistory:
                    $undoHistory,
                redoHistory:
                    $redoHistory
            ) {

                stage = .naming
            }


        case .naming:

            NamingView(
                name:
                    $name,
                route:
                    location.normalizedRoute,
                strokes:
                    strokes,
                topic:
                    topic,
                date:
                    startedAt,
                distance:
                    location.distance,
                duration:
                    duration
            ) {

                saveCard()
            }
        }
    }


    // MARK: - Start Walking

    private func startWalking() {

        startedAt = Date()

        topicAchieved = false

        location.start()

        stage = .walking
    }


    // MARK: - Stop Walking

    private func stopWalking() {

        location.stop()

        duration =
            Date()
                .timeIntervalSince(
                    startedAt
                )

        stage = .drawing
    }


    // MARK: - Load

    private func loadData() {

        if let savedTopics =
            UserDefaults.standard
                .stringArray(
                    forKey: "walkingTopics"
                ),
           savedTopics.count >= 4 {

            topics = savedTopics
        }


        if candidates.isEmpty {

            candidates =
                Array(
                    topics
                        .shuffled()
                        .prefix(4)
                )
        }


        if let data =
            try? Data(
                contentsOf: Self.cardsURL
            ),

           let saved =
            try? JSONDecoder()
                .decode(
                    [WalkCard].self,
                    from: data
                ) {

            cards = saved
        }
    }


    // MARK: - Save

    private func saveCard() {

        let trimmed =
            name.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let card = WalkCard(
            name:
                trimmed.isEmpty
                ? "無題"
                : trimmed,

            route:
                location.normalizedRoute,

            strokes:
                strokes,

            date:
                startedAt,

            distance:
                location.distance,

            duration:
                duration,

            topic:
                topic
        )


        do {

            let data =
                try JSONEncoder()
                    .encode(
                        cards + [card]
                    )

            try data.write(
                to: Self.cardsURL,
                options: .atomic
            )

        } catch {

            saveError = true
            return
        }


        cards.append(card)

        resetAfterSaving()

        tab = 1
    }


    // MARK: - Reset

    private func resetAfterSaving() {

        name = ""

        strokes = []

        undoHistory = []

        redoHistory = []

        ink = 7

        erasing = false

        topic = nil

        topicAchieved = false

        candidates =
            Array(
                topics
                    .shuffled()
                    .prefix(4)
            )

        rotation = 0

        stage = .setup
    }


    // MARK: - Save URL

    private static var cardsURL: URL {

        FileManager.default
            .urls(
                for: .documentDirectory,
                in: .userDomainMask
            )[0]
            .appendingPathComponent(
                "walk-cards.json"
            )
    }
}
