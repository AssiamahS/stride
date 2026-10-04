import SwiftUI

/// One honest question decides where the plan starts. Nobody is forced into Week 1.
struct OnboardingView: View {
    @State private var store = ProgressStore.shared
    @State private var choice: Readiness = .oneMinute

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Where are you today?")
                        .font(.largeTitle.bold())
                    Text("Be honest. Starting too hard is how people quit in week two. We'll build to 5K from wherever you are.")
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 10) {
                    ForEach(Readiness.allCases) { r in
                        Button {
                            choice = r
                        } label: {
                            HStack {
                                Text(r.question)
                                Spacer()
                                Image(systemName: choice == r ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(choice == r ? Color.accentColor : .secondary)
                            }
                            .padding()
                            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()

                let week = Plans.startingWeek(for: choice)
                Text(week == 0 ? "You'll start with Week 0: walking and 30-second jogs. Ten weeks to 5K."
                               : "You'll start at Week \(week). \(10 - week) weeks to a 30-minute run.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button {
                    store.startingWeek = week
                    store.hasOnboarded = true
                    Task { await WorkoutSaver.requestAuthorization() }
                } label: {
                    Text("Start my plan")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
}
