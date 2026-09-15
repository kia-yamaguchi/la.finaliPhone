import SwiftUI


struct DrawingView: View {

    let route: [CGPoint]

    @Binding var strokes: [InkStroke]

    @Binding var ink: Int
    @Binding var erasing: Bool

    @Binding var undoHistory: [[InkStroke]]
    @Binding var redoHistory: [[InkStroke]]

    let onDone: () -> Void


    @State private var current: InkStroke?
    @State private var eraseStarted = false


    var body: some View {

        VStack(spacing: 12) {

            // MARK: - 上部ボタン

            HStack {

                // 戻る
                Button {
                    undo()
                } label: {

                    Image(
                        systemName: "arrow.uturn.backward"
                    )
                }
                .disabled(undoHistory.isEmpty)
                .accessibilityLabel("戻る")


                // 進む
                Button {
                    redo()
                } label: {

                    Image(
                        systemName: "arrow.uturn.forward"
                    )
                }
                .disabled(redoHistory.isEmpty)
                .accessibilityLabel("進む")


                Spacer()


                // 完了
                Button {

                    onDone()

                } label: {

                    Image(
                        systemName: "checkmark"
                    )
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
            .font(.title2)
            .foregroundStyle(.black)


            // MARK: - 描画エリア

            ScrollView(
                [.horizontal, .vertical],
                showsIndicators: false
            ) {

                GeometryReader { geo in

                    Artwork(
                        route: route,

                        strokes:
                            strokes
                            + (
                                current.map {
                                    [$0]
                                }
                                ?? []
                            )
                    )
                    .contentShape(
                        Rectangle()
                    )

                    .gesture(

                        DragGesture(
                            minimumDistance: 0
                        )

                        .onChanged { value in

                            let point =
                                CGPoint(

                                    x:
                                        min(
                                            1,
                                            max(
                                                0,
                                                value.location.x
                                                / geo.size.width
                                            )
                                        ),

                                    y:
                                        min(
                                            1,
                                            max(
                                                0,
                                                value.location.y
                                                / geo.size.height
                                            )
                                        )
                                )


                            // MARK: 消しゴム

                            if erasing {

                                if !eraseStarted {

                                    undoHistory.append(
                                        strokes
                                    )

                                    redoHistory = []

                                    eraseStarted = true
                                }


                                strokes =
                                    erase(
                                        point: point,
                                        from: strokes,
                                        in: geo.size
                                    )

                            } else {

                                // MARK: ペン

                                if current == nil {

                                    current =
                                        InkStroke(
                                            points: [],
                                            color: ink,
                                            width: 3
                                        )
                                }


                                current?
                                    .points
                                    .append(
                                        point
                                    )
                            }
                        }


                        .onEnded { _ in

                            if let current {

                                undoHistory.append(
                                    strokes
                                )

                                redoHistory = []

                                strokes.append(
                                    current
                                )
                            }


                            current = nil

                            eraseStarted = false
                        }
                    )
                }
                .frame(
                    width: 540,
                    height: 540
                )
            }
            .frame(
                maxHeight: 560
            )


            // MARK: - ペン・消しゴム

            HStack(
                alignment: .center,
                spacing: 28
            ) {

                // MARK: 8色のペン

                LazyVGrid(

                    columns: [

                        GridItem(
                            .fixed(36),
                            spacing: 16
                        ),

                        GridItem(
                            .fixed(36),
                            spacing: 16
                        ),

                        GridItem(
                            .fixed(36),
                            spacing: 16
                        ),

                        GridItem(
                            .fixed(36),
                            spacing: 0
                        )
                    ],

                    spacing: 12
                ) {

                    ForEach(
                        AppTheme.palette.indices,
                        id: \.self
                    ) { index in

                        Button {

                            ink = index

                            erasing = false

                        } label: {

                            Circle()
                                .fill(
                                    AppTheme
                                        .palette[index]
                                )
                                .frame(
                                    width: 28,
                                    height: 28
                                )
                                .padding(3)
                                .overlay {

                                    Circle()
                                        .stroke(
                                            ink == index
                                            && !erasing
                                            ? Color.black
                                            : Color.clear,

                                            lineWidth: 2
                                        )
                                }
                        }
                        .buttonStyle(.plain)

                        .accessibilityLabel(
                            colorNames[index]
                        )
                    }
                }
                .frame(
                    width: 192
                )


                // MARK: 消しゴム

                Button {

                    erasing.toggle()

                } label: {

                    Image(
                        systemName: "eraser"
                    )
                    .font(.title)
                    .foregroundStyle(
                        erasing
                        ? AppTheme.coral
                        : Color.black
                    )
                    .padding(8)
                }
                .buttonStyle(.plain)

                .accessibilityLabel(
                    "線を消す"
                )
            }

            // ツール全体を中央へ
            .frame(
                maxWidth: .infinity,
                alignment: .center
            )
        }
        .padding(20)
    }


    // MARK: - Undo

    private func undo() {

        guard
            let previous =
                undoHistory.popLast()
        else {
            return
        }


        redoHistory.append(
            strokes
        )


        strokes =
            previous
    }


    // MARK: - Redo

    private func redo() {

        guard
            let next =
                redoHistory.popLast()
        else {
            return
        }


        undoHistory.append(
            strokes
        )


        strokes =
            next
    }


    // MARK: - Erase

    private func erase(
        point: CGPoint,
        from source: [InkStroke],
        in size: CGSize
    ) -> [InkStroke] {

        var result: [InkStroke] = []


        for stroke in source {

            var segment: [CGPoint] = []


            for p in stroke.points {

                let pixel =
                    CGPoint(
                        x:
                            p.x
                            * size.width,

                        y:
                            p.y
                            * size.height
                    )


                let target =
                    CGPoint(
                        x:
                            point.x
                            * size.width,

                        y:
                            point.y
                            * size.height
                    )


                let distance =
                    hypot(
                        pixel.x
                        - target.x,

                        pixel.y
                        - target.y
                    )


                if distance <= 20 {

                    if segment.count > 1 {

                        result.append(

                            InkStroke(
                                points: segment,
                                color: stroke.color,
                                width: stroke.width
                            )
                        )
                    }


                    segment = []

                } else {

                    segment.append(
                        p
                    )
                }
            }


            if segment.count > 1 {

                result.append(

                    InkStroke(
                        points: segment,
                        color: stroke.color,
                        width: stroke.width
                    )
                )
            }
        }


        return result
    }


    // MARK: - Color Names

    private var colorNames: [String] {

        [
            "赤",
            "オレンジ",
            "黄",
            "緑",
            "青",
            "紫",
            "茶",
            "黒"
        ]
    }
}


// MARK: - Artwork

struct Artwork: View {

    let route: [CGPoint]
    let strokes: [InkStroke]


    var body: some View {

        Canvas { context, size in

            // MARK: 散歩ルート

            draw(
                points: route,
                color: .black,
                width: 3,
                context: &context,
                size: size
            )


            // MARK: 描いた線

            for stroke in strokes {

                let colorIndex =
                    min(
                        max(
                            stroke.color,
                            0
                        ),

                        AppTheme.palette.count - 1
                    )


                draw(
                    points:
                        stroke.points,

                    color:
                        AppTheme
                            .palette[colorIndex],

                    width:
                        stroke.width,

                    context:
                        &context,

                    size:
                        size
                )
            }
        }
        .background(
            .white
        )
        .clipped()
    }


    // MARK: - Draw

    private func draw(
        points: [CGPoint],
        color: Color,
        width: CGFloat,
        context: inout GraphicsContext,
        size: CGSize
    ) {

        guard
            let first =
                points.first
        else {
            return
        }


        let start =
            CGPoint(

                x:
                    first.x
                    * size.width,

                y:
                    first.y
                    * size.height
            )


        // 1点だけの場合
        if points.count == 1 {

            context.fill(

                Path(
                    ellipseIn:
                        CGRect(

                            x:
                                start.x
                                - width / 2,

                            y:
                                start.y
                                - width / 2,

                            width:
                                width,

                            height:
                                width
                        )
                ),

                with:
                    .color(color)
            )


            return
        }


        var path =
            Path()


        path.move(
            to: start
        )


        for point in
            points.dropFirst() {

            path.addLine(

                to:
                    CGPoint(

                        x:
                            point.x
                            * size.width,

                        y:
                            point.y
                            * size.height
                    )
            )
        }


        context.stroke(

            path,

            with:
                .color(color),

            style:
                StrokeStyle(
                    lineWidth: width,
                    lineCap: .round,
                    lineJoin: .round
                )
        )
    }
}
