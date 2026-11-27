#if os(macOS)
import FRICore
import FRIDesign
import SwiftUI

/// All changes stay inside the sheet until the user confirms or explicitly saves a draft.
struct FRIMacPlanEditor: View {
    let calendar: FRICalendarSession
    let editing: Appointment?
    @State private var plans: [Appointment]
    @State private var originals: [Appointment]
    @State private var index = 0
    @State private var closing = false
    @State private var overlap = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    init(calendar: FRICalendarSession, editing: Appointment? = nil) {
        self.calendar = calendar
        self.editing = editing
        var blank = Appointment()
        blank.date = calendar.state.active
        blank.kind = calendar.draftDeadline ? "deadline" : "schedule"
        let saved = calendar.state.drafts
        let selected = saved.filter { item in
            item.id == calendar.draftStartingID || calendar.draftReviewIDs?.contains(item.id) == true
        }
        let initial = (editing ?? calendar.firstPlan).map { [$0] } ?? (selected.isEmpty ? [blank] : selected)
        _plans = State(initialValue: initial)
        _originals = State(initialValue: initial)
    }

    private var dirty: Bool { plans != originals }

    var body: some View {
        FRISheetView(title: editing == nil ? "New plan" : "Edit appointment", onClose: requestClose) {
            Form {
                if plans.count > 1 {
                    Picker("Plan", selection: $index) {
                        ForEach(plans.indices, id: \.self) { i in Text(plans[i].title).tag(i) }
                    }
                }
                FRIPlanFields(draft: $plans[index])
                if let error { Text(error).foregroundStyle(.red).accessibilityIdentifier("fri.editor.error") }
                Button { save() } label: {
                    Text("Confirm").frame(maxWidth: .infinity, minHeight: 36)
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.borderedProminent).controlSize(.large)
                .accessibilityIdentifier("fri.editor.submit")
                if editing == nil && plans.count == 1 && calendar.firstPlan == nil {
                    if !plans[index].title.isEmpty {
                        Button("Save draft and close") {
                            if calendar.addDrafts(plans) { dismiss() } else { takeError() }
                        }
                    }
                    if !calendar.state.drafts.isEmpty && !dirty {
                        Section("Saved drafts") {
                            ForEach(calendar.state.drafts) { item in
                                HStack {
                                    Button(item.title) { plans = [item]; originals = plans; index = 0 }
                                    Spacer()
                                    Button("Remove draft", systemImage: "trash", role: .destructive) {
                                        _ = calendar.change { $0.drafts.removeAll { $0.id == item.id } }
                                    }.labelStyle(.iconOnly)
                                }
                            }
                        }
                    }
                }
            }.formStyle(.grouped).accessibilityIdentifier("fri.editor.form")
        }
        .interactiveDismissDisabled(dirty)
        .onExitCommand(perform: requestClose)
        .alert("Discard your changes?", isPresented: $closing) {
            Button("Keep editing", role: .cancel) {}
            Button("Discard", role: .destructive) { dismiss() }
        }
        .alert("These plans overlap", isPresented: $overlap) {
            Button("Change times", role: .cancel) {}
            Button("Keep both") { save(allowOverlap: true) }
        } message: { Text(error ?? "") }
    }

    private func requestClose() {
        if dirty { closing = true } else { dismiss() }
    }

    private func takeError() {
        error = calendar.message
        calendar.message = nil
    }

    private func save(allowOverlap: Bool = false) {
        for (i, item) in plans.enumerated() {
            let issue: String?
            if item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { issue = "Give your appointment a name." }
            else if CalendarClock.date(item.date) == nil { issue = "Choose a date." }
            else if CalendarClock.minutes(item.time) == nil { issue = "Choose a start time." }
            else if !item.isDeadline && item.duration <= 0 { issue = "Choose a duration in minutes." }
            else if (item.endMinute ?? 0) > 1440 { issue = "This plan ends after midnight. Split it across the two dates." }
            else { issue = nil }
            if let issue { index = i; error = issue; return }
        }
        if calendar.save(plans, editing: editing, allowOverlap: allowOverlap) {
            calendar.select(plans[0].date)
            dismiss()
        } else {
            takeError()
            overlap = error?.hasPrefix("This time overlaps") == true
        }
    }
}

struct FRIMacTimeField: View {
    @Binding var value: String
    @State private var picking = false

    var body: some View {
        Button(value.isEmpty ? "Choose time" : value) { picking = true }
            .accessibilityLabel("Start time").accessibilityValue(value)
            .accessibilityIdentifier("fri.editor.time")
            .sheet(isPresented: $picking) {
                FRIMacTimePicker(value: value) { value = $0; picking = false }
            }
    }
}

private struct FRIMacTimePicker: View {
    let confirm: (String) -> Void
    @State private var values: [Int]
    @FocusState private var focus: Int?
    @Environment(\.dismiss) private var dismiss
    private let ranges = [Array(1...12), Array(0...59), [0, 1]]
    private let labels = ["Hour", "Minute", "AM or PM"]

    init(value: String, confirm: @escaping (String) -> Void) {
        self.confirm = confirm
        let minutes = CalendarClock.minutes(value) ?? 540
        _values = State(initialValue: [(minutes / 60 + 11) % 12 + 1, minutes % 60, minutes / 720])
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Start time").friFont(.title2, weight: .semibold)
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            HStack {
                ForEach(0..<3) { i in wheel(i) }
            }
            Button(action: apply) { Text("Confirm").frame(maxWidth: .infinity, minHeight: 36) }
                .keyboardShortcut(.defaultAction).controlSize(.large).buttonStyle(.borderedProminent)
                .accessibilityIdentifier("fri.time.confirm")
        }.padding(24).frame(width: 390).background(FRIColors.surface)
            .onAppear { focus = 0 }
    }

    private func display(_ n: Int, _ i: Int) -> String {
        if i == 2 { return n == 0 ? "AM" : "PM" }
        return i == 1 ? String(format: "%02d", n) : String(n)
    }

    private func wheel(_ i: Int) -> some View {
        let selection = Binding<Int?>(
            get: { values[i] },
            set: { row in if let row, ranges[i].contains(row) { values[i] = row } }
        )
        return ScrollView {
            VStack(spacing: 0) {
                ForEach(ranges[i], id: \.self) { n in
                    Button {
                        values[i] = n
                        focus = i
                    } label: {
                        Text(display(n, i)).friFont(.title2, weight: values[i] == n ? .semibold : .regular)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain).focusable(false).id(n)
                        .accessibilityIdentifier("fri.time.\(i).\(n)")
                }
            }.scrollTargetLayout()
        }
            .contentMargins(.vertical, 66, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: selection, anchor: .center)
            .scrollIndicators(.hidden)
            .frame(height: 176)
            .background { RoundedRectangle(cornerRadius: 8).fill(FRIColors.tint).frame(height: 44) }
            .focusable().focused($focus, equals: i)
            .accessibilityLabel(labels[i]).accessibilityValue(display(values[i], i))
            .accessibilityAdjustableAction { direction in step(i, direction == .increment ? 1 : -1) }
            .onKeyPress(phases: [.down, .repeat]) { key in
                switch key.key {
                case .upArrow: step(i, -1)
                case .downArrow: step(i, 1)
                case .home: values[i] = ranges[i][0]
                case .end: values[i] = ranges[i].last!
                case .pageUp: step(i, -5)
                case .pageDown: step(i, 5)
                case .leftArrow: focus = max(0, i - 1)
                case .rightArrow: focus = min(2, i + 1)
                case .return: apply()
                default:
                    guard i == 2, ["a", "p"].contains(key.characters.lowercased()) else { return .ignored }
                    values[i] = key.characters.lowercased() == "a" ? 0 : 1
                }
                return .handled
            }
    }

    private func step(_ i: Int, _ amount: Int) {
        values[i] = min(ranges[i].last!, max(ranges[i][0], values[i] + amount))
    }

    private func apply() {
        confirm(String(format: "%02d:%02d", values[0] % 12 + values[2] * 12, values[1]))
    }
}
#endif
