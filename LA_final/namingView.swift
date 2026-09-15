import SwiftUI

struct NamingView: View {

    @Binding var name: String

    let route: [CGPoint]
    let strokes: [InkStroke]

    let topic: String?
    let date: Date
    let distance: Double
    let duration: TimeInterval

    let onSave: () -> Void


    var body: some View {

        ScrollView {

            VStack(spacing: 16) {

                // MARK: Save

                HStack {

                    Spacer()

                    Button {

                        onSave()

                    } label: {

                        Image(systemName: "checkmark")
                            .font(.title2)
                            .foregroundStyle(.black)
                            .frame(
                                width: 44,
                                height: 44
                            )
                            .background(
                                AppTheme.coral,
                                in: Circle()
                            )
                    }
                    .accessibilityLabel("完了")
                }


                // MARK: Name

                TextField(
                    "名前",
                    text: $name
                )
                .textFieldStyle(.roundedBorder)


                // MARK: Artwork

                Artwork(
                    route: route,
                    strokes: strokes
                )
                .aspectRatio(
                    1,
                    contentMode: .fit
                )


                // MARK: Metadata

                WalkMetadataView(
                    topic: topic,
                    date: date,
                    distance: distance,
                    duration: duration
                )
            }
            .padding(20)
        }
    }
}


// MARK: - Metadata

struct WalkMetadataView: View {

    let topic: String?
    let date: Date
    let distance: Double
    let duration: TimeInterval

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 8
        ) {

            Text(
                "お題：\(topic ?? "お題なし")"
            )

            Text(
                "日付：\(date.formatted(date: .numeric, time: .omitted))"
            )

            Text(
                String(
                    format:
                        "歩行距離：%.2f km",
                    distance / 1000
                )
            )

            Text(
                "歩行時間：\(Int(duration) / 60)分\(Int(duration) % 60)秒"
            )
        }
        .font(.subheadline)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding()
        .background(
            Color.gray.opacity(0.2)
        )
    }
}
