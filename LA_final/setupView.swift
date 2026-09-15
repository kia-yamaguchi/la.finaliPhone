import SwiftUI

struct SetupView: View {

    @Binding var topics: [String]
    @Binding var candidates: [String]
    @Binding var topic: String?

    @Binding var rotation: Double
    @Binding var spinning: Bool

    let onStart: () -> Void

    @State private var showAdd = false
    @State private var newTopic = ""

    @FocusState private var topicFocus: Bool


    var body: some View {

        VStack(spacing: 30) {

            // MARK: - お題追加

            HStack {

                VStack(spacing: 2) {

                    Button {
                        showAdd = true
                    } label: {

                        Image(systemName: "plus")
                            .font(.system(size: 30))
                            .foregroundStyle(.black)
                            .frame(
                                width: 48,
                                height: 48
                            )
                    }
                    .disabled(spinning)
                    .accessibilityLabel("お題を追加")


                    Button {
                        showAdd = true
                    } label: {

                        Text("お題を追加")
                            .font(.system(size: 11))
                            .foregroundStyle(.black)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .frame(width: 48)
                    }
                    .buttonStyle(.plain)
                    .disabled(spinning)
                }

                Spacer()
            }


            Spacer()


            // MARK: - ルーレット

            ZStack {

                ZStack {

                    ForEach(
                        candidates.indices,
                        id: \.self
                    ) { index in

                        WheelSlice(index: index)
                            .fill(
                                index.isMultiple(of: 2)
                                ? AppTheme.coral
                                : AppTheme.lightPink
                            )


                        Text(candidates[index])
                            .font(.system(size: 13))
                            .multilineTextAlignment(.center)
                            .frame(
                                width: 83,
                                height: 65
                            )
                            .rotationEffect(
                                .degrees(
                                    Double(index) * 90
                                )
                            )
                            .offset(
                                x:
                                    cos(
                                        Double(index)
                                        * Double.pi / 2
                                        - Double.pi / 2
                                    ) * 82,

                                y:
                                    sin(
                                        Double(index)
                                        * Double.pi / 2
                                        - Double.pi / 2
                                    ) * 82
                            )
                    }
                }
                .frame(
                    width: 280,
                    height: 280
                )
                .rotationEffect(
                    .degrees(rotation)
                )


                // MARK: GO

                Button {
                    spin()
                } label: {

                    Text("GO")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(
                            width: 50,
                            height: 50
                        )
                        .background(
                            .white,
                            in: Circle()
                        )
                }
                .disabled(spinning)


                // MARK: 矢印

                Image(
                    systemName:
                        "arrowtriangle.down.fill"
                )
                .font(.system(size: 22))
                .foregroundStyle(.black)
                .offset(y: -145)
                .allowsHitTesting(false)
            }
            .frame(height: 300)


            // MARK: - START

            Button {

                onStart()

            } label: {

                VStack(spacing: 5) {

                    Image(systemName: "play")
                        .font(
                            .system(size: 34)
                        )

                    Text("START")
                        .font(.system(size: 16))
                }
                .frame(
                    width: 110,
                    height: 75
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(
                StartButtonStyle()
            )
            .disabled(spinning)


            Spacer()
        }
        .padding(.horizontal, 20)

        .sheet(
            isPresented: $showAdd
        ) {
            addTopicView
        }
    }


    // MARK: - Spin

    private func spin() {

        guard
            !spinning,
            candidates.count == 4
        else {
            return
        }


        spinning = true


        let index =
            Int.random(
                in: 0..<4
            )


        let target =
            Double(
                (4 - index) % 4
            ) * 90


        withAnimation(
            .easeOut(
                duration: 2
            )
        ) {

            rotation =
                (floor(rotation / 360) + 4)
                * 360
                + target
        }


        DispatchQueue.main.asyncAfter(
            deadline: .now() + 2
        ) {

            topic =
                candidates[index]

            spinning =
                false
        }
    }


    // MARK: - お題追加

    private var addTopicView:
        some View {

        VStack(spacing: 20) {

            Text("お題を追加")
                .font(.headline)


            TextField(
                "お題を入力",
                text: $newTopic
            )
            .textFieldStyle(
                .roundedBorder
            )
            .focused(
                $topicFocus
            )


            Button("追加") {

                let trimmed =
                    newTopic
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )


                guard
                    !trimmed.isEmpty
                else {
                    return
                }


                topics.append(
                    trimmed
                )


                UserDefaults.standard.set(
                    topics,
                    forKey:
                        "walkingTopics"
                )


                candidates =
                    Array(
                        topics
                            .shuffled()
                            .prefix(4)
                    )


                topic = nil

                rotation = 0

                newTopic = ""

                showAdd = false
            }
            .disabled(
                newTopic
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )
                    .isEmpty
            )
        }
        .padding(24)
        .presentationDetents(
            [.medium]
        )
        .onAppear {

            topicFocus = true
        }
    }
}


// MARK: - START Button Style

private struct StartButtonStyle:
    ButtonStyle {

    func makeBody(
        configuration: Configuration
    ) -> some View {

        configuration.label
            .foregroundStyle(
                configuration.isPressed
                ? AppTheme.coral
                : Color.black
            )
    }
}


// MARK: - Wheel

struct WheelSlice: Shape {

    let index: Int


    func path(
        in rect: CGRect
    ) -> Path {

        var path =
            Path()


        let center =
            CGPoint(
                x: rect.midX,
                y: rect.midY
            )


        path.move(
            to: center
        )


        path.addArc(
            center: center,

            radius:
                rect.width / 2,

            startAngle:
                .degrees(
                    Double(index)
                    * 90
                    - 135
                ),

            endAngle:
                .degrees(
                    Double(index)
                    * 90
                    - 45
                ),

            clockwise: false
        )


        path.closeSubpath()


        return path
    }
}
