import AVFoundation
import FRICore
import FRIDesign
import SwiftUI

struct FRIDayMessage: Identifiable, Sendable {
    let id = UUID()
    let text: String
    let fromUser: Bool

    static let greeting = FRIDayMessage(
        text: "Hi, I’m Day. A little less on your mind, a little more room in your day. What shall we make time for?",
        fromUser: false
    )
}

/// Desktop 0.5's local conversation; no remote AI or account is involved.
struct FRIDayAssistantView: View {
    let calendar: FRICalendarSession
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var message = ""
    @State private var speech = AVSpeechSynthesizer()
    @State private var draftTitle: String?
    @State private var error: String?

    var body: some View {
        FRISheetView(title: "A little help from Day") {
            ScrollViewReader { outerProxy in
                ScrollView {
                    VStack(spacing: 16) {
                        HStack(spacing: 18) {
                            Image("DayBackdrop").resizable().scaledToFit().frame(width: 85, height: 85).accessibilityHidden(true)
                            Text("Your day, with a little company.").friFont(.title3)
                        }
                        if verticalSizeClass == .compact {
                            conversation
                        } else {
                            ScrollViewReader { proxy in
                                ScrollView { conversation }
                                    .accessibilityIdentifier("fri.day.history")
                                    .onAppear { proxy.scrollTo("conversation-end", anchor: .bottom) }
                                    .onChange(of: calendar.dayHistory.last?.id) { _, _ in
                                        proxy.scrollTo("conversation-end", anchor: .bottom)
                                    }
                            }.frame(height: 230)
                        }
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), alignment: .leading)], alignment: .leading, spacing: 8) {
                            suggestions
                        }.buttonStyle(FRIDayChipStyle())
                        HStack {
                            TextField("Message Day", text: $message).textFieldStyle(FRISheetTextFieldStyle())
                                .onSubmit(send).accessibilityIdentifier("fri.day.message")
                            Button(action: send) {
                                Image(systemName: "arrow.up").frame(width: 46, height: 46)
                                    .background(FRIColors.marsala, in: RoundedRectangle(cornerRadius: 14))
                            }.buttonStyle(.plain).accessibilityLabel("Send")
                                .accessibilityIdentifier("fri.day.send")
                                .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        if let error { Text(error).foregroundStyle(.red) }
                        Text("Day uses local rules, just like the desktop preview. No AI service is connected. Use your keyboard’s Dictation to enter text by voice.")
                            .friFont(.caption).foregroundStyle(.secondary)
                    }.padding(20)
                }
                .accessibilityIdentifier("fri.day.content")
                .scrollDismissesKeyboard(.interactively)
                .onAppear {
                    if verticalSizeClass == .compact { outerProxy.scrollTo("conversation-end", anchor: .bottom) }
                }
                .onChange(of: calendar.dayHistory.last?.id) { _, _ in
                    if verticalSizeClass == .compact { outerProxy.scrollTo("conversation-end", anchor: .bottom) }
                }
                .onChange(of: verticalSizeClass) { _, size in
                    if size == .compact { outerProxy.scrollTo("conversation-end", anchor: .bottom) }
                }
            }
        }
        .onDisappear { speech.stopSpeaking(at: .immediate) }
    }

    private var conversation: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            ForEach(calendar.dayHistory) { item in
                HStack(spacing: 0) {
                    if item.fromUser { Spacer(minLength: 24) }
                    Text(item.text).textSelection(.enabled)
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(FRIColors.cream)
                        .background(item.fromUser ? FRIColors.marsala : FRIColors.dialogControl,
                                    in: UnevenRoundedRectangle(topLeadingRadius: 18,
                                        bottomLeadingRadius: item.fromUser ? 18 : 4,
                                        bottomTrailingRadius: item.fromUser ? 4 : 18,
                                        topTrailingRadius: 18))
                    if !item.fromUser { Spacer(minLength: 24) }
                }.id(item.id)
            }
            if let draftTitle {
                Button("Create this appointment") { createDraft(draftTitle) }
                    .buttonStyle(.borderedProminent).tint(FRIColors.marsala).foregroundStyle(FRIColors.cream)
                    .accessibilityIdentifier("fri.day.create")
            }
            Color.clear.frame(height: 1).id("conversation-end")
        }
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
        calendar.dayHistory.append(FRIDayMessage(text: text, fromUser: true))
        let creates = ["walk", "create", "add", "schedule", "appointment", "make time"].contains { text.localizedCaseInsensitiveContains($0) }
        draftTitle = creates ? (text.localizedCaseInsensitiveContains("walk") ? "A little walk" : String(text.prefix(160))) : nil
        calendar.dayHistory.append(FRIDayMessage(text: creates ? "Let’s give that a little room. Open an appointment draft to choose the day, time and details." : summary, fromUser: false))
        if calendar.dayHistory.count > 100 { calendar.dayHistory.removeFirst(calendar.dayHistory.count - 100) }
    }

    private func createDraft(_ title: String) {
        var item = Appointment()
        item.title = title
        item.date = calendar.state.active
        item.kind = "schedule"
        guard calendar.addDrafts([item]) else { error = calendar.message; return }
        calendar.newDraft(deadline: false, startingID: item.id)
    }
}

private struct FRIDayChipStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .foregroundStyle(FRIColors.cream)
            .background(FRIColors.dialogControl.opacity(configuration.isPressed ? 0.7 : 1),
                        in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(FRIColors.cream.opacity(0.16)))
            .contentShape(RoundedRectangle(cornerRadius: 12))
    }
}
