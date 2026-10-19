import SwiftUI

/// A 4:5 story-sized card of a finished run, rendered to a UIImage for the share sheet.
enum ShareCard {
    @MainActor
    static func render(_ run: CompletedRun) -> UIImage? {
        let view = ShareCardView(run: run).frame(width: 1080, height: 1350)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(width: 1080, height: 1350)
        return renderer.uiImage
    }
}

struct ShareCardView: View {
    let run: CompletedRun

    private var pace: String {
        Fmt.pace(run.meters > 100 ? Double(run.seconds) / (run.meters / 1000) : nil)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color(red: 0.05, green: 0.07, blue: 0.14), Color(red: 0.02, green: 0.02, blue: 0.05)],
                           startPoint: .top, endPoint: .bottom)
            Circle()
                .fill(Color.accentColor.opacity(0.35))
                .frame(width: 900, height: 900)
                .blur(radius: 160)
                .offset(x: 350, y: 650)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("STRIDE").font(.system(size: 44, weight: .black, design: .rounded)).tracking(6)
                    Spacer()
                    Text(run.date, format: .dateTime.weekday(.wide).month().day())
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.bottom, 120)

                Text(run.workout?.title ?? "Guided run")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Text(Fmt.distance(run.meters))
                    .font(.system(size: 190, weight: .black, design: .rounded).monospacedDigit())
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .padding(.top, -10)

                HStack(spacing: 60) {
                    stat("TIME", Fmt.clock(TimeInterval(run.seconds)))
                    stat("PACE", pace)
                    if let hr = run.avgHeartRate { stat("AVG BPM", "\(Int(hr))") }
                }
                .padding(.top, 30)

                Spacer()

                if let w = run.workout {
                    SegmentBar(segments: w.segments).frame(height: 18)
                        .padding(.bottom, 24)
                    Text(w.subtitle).font(.system(size: 30)).foregroundStyle(.white.opacity(0.7))
                }
                Text(run.indoor ? "Treadmill · coached in my own voice" : "Coached in my own voice")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.top, 10)
            }
            .padding(80)
        }
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.system(size: 64, weight: .bold, design: .rounded).monospacedDigit())
            Text(label).font(.system(size: 26, weight: .heavy)).foregroundStyle(.white.opacity(0.6))
        }
    }
}
