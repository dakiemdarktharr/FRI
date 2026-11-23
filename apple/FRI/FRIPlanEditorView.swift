import FRICore
import SwiftUI

struct FRISheetView<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(title)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
        #if os(macOS)
        .frame(minWidth: 510, minHeight: 430)
        #endif
    }
}

struct FRIPlanEditorView: View {
    let calendar: FRICalendarSession
    var editing: Appointment?
    @Environment(\.dismiss) private var dismiss
    @State private var draft = Appointment()
    @State private var reviewing = false
    @State private var queue: [Appointment] = []
    @State private var saved = false
    @State private var askOverlap = false
    @State private var error: String?
    @State private var missingTime = ""
    @State private var missingDuration = 0

    private var missing: Appointment? { queue.first { $0.time.isEmpty || (!$0.isDeadline && $0.duration == 0) } }

    var body: some View {
        FRISheetView(title: title) {
            Form {
                if reviewing {
                    if let item = missing { clarification(item) }
                    else { reviewSummary }
                } else {
                    FRIPlanFields(draft: $draft)
                    if editing == nil, !calendar.state.drafts.isEmpty {
                        Section("Saved drafts") {
                            ForEach(calendar.state.drafts) { item in
                                HStack {
                                    Text(item.title)
                                    Spacer()
                                    Button("Remove draft", systemImage: "trash", role: .destructive) {
                                        _ = calendar.change { $0.drafts.removeAll { $0.id == item.id } }
                                    }.labelStyle(.iconOnly).buttonStyle(.borderless)
                                }
                            }
                            Button("Review saved drafts") { startReview(calendar.state.drafts) }
                        }
                    }
                    if editing == nil {
                        Button("Add another") {
                            guard stashDraft() else { return }
                            resetDraft()
                        }.disabled(draft.title.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    Button("Done") { submitForm() }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("fri.editor.submit")
                }
                if let error { Text(error).foregroundStyle(.red) }
            }.formStyle(.grouped)
        }
        .onAppear { if let editing { draft = editing } else { resetDraft() } }
        .onDisappear {
            if editing == nil, !saved, !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               (try? draft.validate(draft: true)) != nil,
               !calendar.state.drafts.contains(where: { $0.id == draft.id }) {
                _ = calendar.addDrafts([draft])
            }
        }
        .alert("These plans overlap", isPresented: $askOverlap) {
            Button("Change times", role: .cancel) { reviewing = false }
            Button("Keep both") { finish(allowOverlap: true) }
        } message: {
            Text(error ?? "Confirm that you want to keep the overlapping appointments.")
        }
    }

    private var title: String {
        if editing != nil { return "Edit appointment" }
        if reviewing { return "Review plans" }
        return draft.isDeadline ? "New deadline" : "New schedule"
    }

    private func resetDraft() {
        draft = Appointment()
        draft.date = calendar.state.active
        draft.kind = calendar.draftDeadline ? "deadline" : "schedule"
    }

    private func stashDraft() -> Bool {
        guard draftLooksValid() else { return false }
        if calendar.addDrafts([draft]) { return true }
        captureError()
        return false
    }

    private func draftLooksValid() -> Bool {
        do {
            try draft.validate(draft: true)
            guard !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw CalendarError.invalidAppointment
            }
            error = nil
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    private func submitForm() {
        if editing != nil {
            guard draftLooksValid() else { return }
            startReview([draft])
        } else {
            if !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !stashDraft() { return }
            guard !calendar.state.drafts.isEmpty else {
                error = "Give your appointment a name."
                return
            }
            startReview(calendar.state.drafts)
        }
    }

    private func startReview(_ items: [Appointment]) {
        queue = items
        reviewing = true
        resetQuestion()
        if missing == nil { finish() }
    }

    private func resetQuestion() {
        missingTime = ""
        missingDuration = 0
        error = nil
    }

    private func clarification(_ item: Appointment) -> some View {
        Section(item.time.isEmpty ? (item.isDeadline ? "When is it due?" : "When shall we begin?") : "How much time does it need?") {
            Text(item.title)
            if item.time.isEmpty {
                TextField("Time (HH:mm)", text: $missingTime).accessibilityIdentifier("fri.editor.missingTime")
            } else {
                TextField("Duration in minutes", value: $missingDuration, format: .number)
                    .accessibilityIdentifier("fri.editor.missingDuration")
            }
            Button("Continue") {
                guard let index = queue.firstIndex(where: { $0.id == item.id }) else { return }
                var updated = item
                if item.time.isEmpty {
                    guard CalendarClock.minutes(missingTime) != nil else { error = "Enter a time from 00:00 to 23:59."; return }
                    updated.time = missingTime
                } else {
                    guard missingDuration > 0 else { error = "Enter a positive duration."; return }
                    updated.duration = missingDuration
                }
                do { try updated.validate(draft: true) }
                catch { self.error = error.localizedDescription; return }
                if editing == nil, !calendar.addDrafts([updated]) { captureError(); return }
                queue[index] = updated
                resetQuestion()
                if missing == nil { finish() }
            }
            .accessibilityIdentifier("fri.editor.continue")
            Button("Back to plans") { reviewing = false }
        }
    }

    private var reviewSummary: some View {
        Section("Plans to save") {
            ForEach(queue) { item in
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.title)
                    Text("\(item.date) · \(item.time)").font(.caption).foregroundStyle(.secondary)
                    TextField("Adjust time (HH:mm)", text: Binding(get: { item.time }, set: { value in
                        if let index = queue.firstIndex(where: { $0.id == item.id }) { queue[index].time = value }
                    }))
                }
            }
            Button("Save plans") { finish() }
            Button("Back to plans") { reviewing = false }
        }
    }

    private func finish(allowOverlap: Bool = false) {
        if calendar.save(queue, editing: editing, allowOverlap: allowOverlap) {
            saved = true
            if let day = queue.first?.date { calendar.select(day) }
            dismiss()
        } else {
            captureError()
            askOverlap = error?.hasPrefix("This time overlaps") == true
        }
    }

    private func captureError() {
        error = calendar.message
        calendar.message = nil
    }
}

struct FRIPlanFields: View {
    @Binding var draft: Appointment

    var body: some View {
        Section("Appointment") {
            TextField("Name", text: $draft.title).accessibilityIdentifier("fri.editor.title")
            Picker("Type", selection: Binding(get: { draft.isDeadline }, set: { deadline in
                draft.kind = deadline ? "deadline" : "schedule"
                if deadline { draft.duration = 0 }
            })) {
                Text("Schedule").tag(false)
                Text("One-time deadline").tag(true)
            }
            DatePicker("Date", selection: Binding(get: { CalendarClock.date(draft.date) ?? .now }, set: {
                draft.date = CalendarClock.day($0)
            }), displayedComponents: .date)
            TextField("Time (HH:mm)", text: $draft.time).accessibilityIdentifier("fri.editor.time")
            if !draft.isDeadline {
                TextField("Duration in minutes", value: $draft.duration, format: .number)
                    .accessibilityIdentifier("fri.editor.duration")
            }
            TextField("Category", text: $draft.category)
            TextField("Location", text: $draft.location)
            TextField("Notes", text: $draft.notes, axis: .vertical)
        }
    }
}

struct FRIPlanDetailView: View {
    let item: Appointment
    let calendar: FRICalendarSession
    @State private var editing: Appointment?

    var body: some View {
        let current = calendar.state.tasks.first { $0.id == item.id } ?? item
        if let editing {
            FRIPlanEditorView(calendar: calendar, editing: editing)
        } else {
            FRISheetView(title: current.title) {
                Form {
                    LabeledContent("Date", value: current.date)
                    LabeledContent("Time", value: current.time)
                    if current.isDeadline { LabeledContent("Type", value: "Deadline") }
                    else { LabeledContent("Duration", value: "\(current.duration) min") }
                    if !current.location.isEmpty { LabeledContent("Location", value: current.location) }
                    if !current.notes.isEmpty { Text(current.notes) }
                    Button(current.done ? "Mark as pending" : "Done", systemImage: "checkmark.circle") { calendar.setDone(current) }
                        .accessibilityIdentifier("fri.detail.done")
                    Button("Edit", systemImage: "pencil") { editing = current }
                    Button("Delete", systemImage: "trash", role: .destructive) { calendar.remove([current.id]) }
                }.formStyle(.grouped)
            }
        }
    }
}
