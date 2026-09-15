import SwiftUI

struct BookView: View {

    let cards: [WalkCard]

    @State private var selectedCard: WalkCard?

    var body: some View {

        NavigationStack {

            ScrollView {

                if cards.isEmpty {

                    Text(
                        "作品を保存すると、ここに並びます"
                    )
                    .padding(.top, 80)

                } else {

                    LazyVGrid(
                        columns:
                            Array(
                                repeating:
                                    GridItem(.flexible()),
                                count: 3
                            ),
                        spacing: 20
                    ) {

                        ForEach(cards) { card in

                            Button {

                                selectedCard = card

                            } label: {

                                VStack {

                                    Artwork(
                                        route: card.route,
                                        strokes: card.strokes
                                    )
                                    .aspectRatio(
                                        1,
                                        contentMode: .fit
                                    )


                                    Text(card.name)
                                        .font(.caption)
                                        .foregroundStyle(.black)
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .background(AppTheme.paper)
            .navigationTitle("図鑑")

            .toolbar {

                ToolbarItem(
                    placement: .topBarTrailing
                ) {

                    Text(badgeSymbol)
                        .font(.title2)
                        .accessibilityLabel("バッジ")
                }
            }
        }

        .sheet(item: $selectedCard) { card in

            DetailView(card: card)
        }
    }


    // MARK: - Badge

    private var badgeSymbol: String {

        if cards.count >= 10 {
            return "🏆"
        }

        if cards.count >= 5 {
            return "🥇"
        }

        if cards.count >= 1 {
            return "🏅"
        }

        return "○"
    }
}


// MARK: - Detail

private struct DetailView: View {

    let card: WalkCard

    var body: some View {

        NavigationStack {

            ScrollView {

                VStack(
                    alignment: .leading,
                    spacing: 16
                ) {

                    Text(card.name)
                        .font(.title2)


                    Artwork(
                        route: card.route,
                        strokes: card.strokes
                    )
                    .aspectRatio(
                        1,
                        contentMode: .fit
                    )


                    WalkMetadataView(
                        topic: card.topic,
                        date: card.date,
                        distance: card.distance,
                        duration: card.duration
                    )
                }
                .padding(20)
            }
            .background(AppTheme.paper)

            .navigationTitle("作品詳細")

            .navigationBarTitleDisplayMode(
                .inline
            )
        }
        .presentationDetents([
            .medium,
            .large
        ])
        .presentationDragIndicator(
            .visible
        )
    }
}
