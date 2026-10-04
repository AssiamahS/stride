import SwiftUI

struct PlanView: View {
    @State private var store = ProgressStore.shared
    @State private var activeWorkout: Workout?
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(Plans.couchTo5K.title).font(.title2.bold())
                        ProgressView(value: store.planProgress)
                        Text("Three runs a week. Rest or walk on the other days. If a week felt rough, repeat it. Nothing is lost.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
                ForEach(store.activeWeeks) { week in
                    Section("Week \(week.week) · \(week.theme)") {
                        ForEach(week.workouts) { w in
                            Button { activeWorkout = w } label: {
                                HStack {
                                    Image(systemName: store.isDone(w) ? "checkmark.circle.fill" : (store.nextWorkout?.id == w.id ? "play.circle.fill" : "circle"))
                                        .foregroundStyle(store.isDone(w) ? .green : Color.accentColor)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(w.title).foregroundStyle(.primary)
                                        Text(w.subtitle).font(.footnote).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(w.durationText).font(.footnote).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                Section {
                    Button("Change starting point", role: .destructive) { confirmReset = true }
                }
            }
            .navigationTitle("Plan")
            .confirmationDialog("Pick a new starting week? Your run history stays.", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Choose again") { store.hasOnboarded = false }
            }
            .fullScreenCover(item: $activeWorkout) { w in RunView(workout: w) }
        }
    }
}
