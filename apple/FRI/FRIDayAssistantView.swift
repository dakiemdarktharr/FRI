import AVFoundation
import FRICore
import FRIDesign
import SwiftUI

/// Desktop 0.5's local conversation; no remote AI or account is involved.
struct FRIDayAssistantView: View {
    let calendar: FRICalendarSession
    @State private var message = ""
    @State private var history: [Message] = []
    @State private var speech = AVSpeechSynthesizer()
    @State private var draftTitle: String?
    @State private var error: String?

    private struct Message: Identifiable {
        let id = UUID()
        let text: String
        let fromUser: Bool
    }

    var body: some View {
        FRISheetView(title: "A little help from Day") {
            VStack(spacing: 16) {
                HStack(spacing: 18) {
                    Image("DayBackdrop").resizable().scaledToFit().frame(width: 85, height: 85).accessibilityHidden(true)
                    Text("Your day, with a little company.").font(.title3)
                }
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(history) { item in
                                Text(item.text).textSelection(.enabled)
                                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                                    .foregroundStyle(item.fromUser ? FRIColors.cream : FRIColors.ink)
                                    .background(item.fromUser ? FRIColors.marsala : FRIColors.cream,
                                                in: RoundedRectangle(cornerRadius: 16))
                                    .id(item.id)
                            }
                            if let draftTitle {
                                Button("Create this appointment") { createDraft(draftTitle) }
                                    .buttonStyle(.borderedProminent).tint(FRIColors.marsala).foregroundStyle(FRIColors.cream)
                                    .accessibilityIdentifier("fri.day.create")
                            }
                        }
                    }
                    .onChange(of: history.count) { _, _ in
                        if let last = history.last { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
                ViewThatFits {
                    HStack { suggestions }
                    VStack(alignment: .leading) { suggestions }
                }
                HStack {
                    TextField("Message Day", text: $message).textFieldStyle(FRISheetTextFieldStyle())
                        .onSubmit(send).accessibilityIdentifier("fri.day.message")
                    Button("Send", systemImage: "arrow.up") { send() }
                        .labelStyle(.iconOnly).disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                if let error { Text(error).foregroundStyle(.red) }
                Text("Day uses local rules, just like the desktop preview. No AI service is connected. Use your keyboard’s Dictation to enter text by voice.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(20)
        }
        .onDisappear { speech.stopSpeaking(at: .immediate) }
    }

    @ViewBuilder private var suggestions: some View {
        Button("What’s coming up?") { answer("What’s coming up?") }
        Button("Make time for a walk") { answer("Make time for a walk") }
        Button("Read my day", systemImage: "speaker.wave.2") {
            speech.stopSpeaking(at: .immediate)
            let utterance = AVSpeechUtterance(string: summary)
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            speech.speak(utterance)
        }
        Button("Stop reading", systemImage: "stop.fill") { speech.stopSpeaking(at: .immediate) }
    }

    private var summary: String {
        let pending = calendar.state.tasks(on: calendar.state.active).filter { !$0.done }
        guard !pending.isEmpty else { return "You have a little breathing room. There are no unfinished plans on this day." }
        return "You have \(pending.count) plans still to enjoy. "
            + pending.prefix(3).map { "\($0.title) at \($0.time)" }.joined(separator: ". ")
            + ". We can take them one at a time."
    }

    private func send() {
        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        message = ""
        answer(String(text.prefix(500)))
    }

    private func answer(_ text: String) {
        history.append(Message(text: text, fromUser: true))
        let creates = ["walk", "create", "add", "schedule", "appointment", "make time"].contains { text.localizedCaseInsensitiveContains($0) }
        draftTitle = creates ? (text.localizedCaseInsensitiveContains("walk") ? "A little walk" : String(text.prefix(160))) : nil
        history.append(Message(text: creates ? "Let’s give that a little room. Open an appointment draft to choose the day, time and details." : summary, fromUser: false))
        if history.count > 100 { history.removeFirst(history.count - 100) }
    }

    private func createDraft(_ title: String) {
        var item = Appointment()
        item.title = title
        item.date = calendar.state.active
        item.kind = "schedule"
        guard calendar.addDrafts([item]) else { error = calendar.message; return }
        calendar.newDraft(deadline: false)
    }
}
