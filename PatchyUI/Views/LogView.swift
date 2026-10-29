import AppKit
import Observation
import PatchyKit
import SwiftUI

enum LogKind: String {
    case errors, visits
}

struct LogLine: Identifiable, Equatable {
    let id: Int
    let text: String

    /// Fatal PHP errors and 5xx responses stand out.
    var isBad: Bool { text.contains(PatchyOutput.fatal) || text.range(of: #"" 5\d\d "#, options: .regularExpression) != nil }
}

@MainActor
@Observable
final class LogViewModel {
    private(set) var lines: [LogLine] = []
    var filter = ""
    var selected: Set<Int> = []
    private(set) var live = true

    @ObservationIgnored private var tailer: LogTailer?
    @ObservationIgnored private var held: [String] = []
    @ObservationIgnored private var nextID = 0
    @ObservationIgnored private var generation = 0
    private static let limit = 2000

    func follow(_ file: URL) {
        tailer?.stop()
        generation += 1
        lines = []
        held = []
        selected = []
        filter = ""
        live = true
        let current = generation
        let tailer = LogTailer(file: file)
        tailer.start { [weak self] new in
            Task { @MainActor in
                guard let self, self.generation == current else { return }
                self.receive(new)
            }
        }
        self.tailer = tailer
    }

    func stop() {
        tailer?.stop()
        tailer = nil
        generation += 1
    }

    private func receive(_ new: [String]) {
        if live { append(new) } else { held.append(contentsOf: new) }
    }

    private func append(_ new: [String]) {
        for text in new {
            lines.append(LogLine(id: nextID, text: text))
            nextID += 1
        }
        if lines.count > Self.limit { lines.removeFirst(lines.count - Self.limit) }
    }

    func toggleLive() {
        live.toggle()
        if live {
            append(held)
            held = []
        }
    }

    /// Clears what is shown, not the file.
    func clear() {
        lines = []
        held = []
        selected = []
    }

    var visible: [LogLine] {
        let query = filter.lowercased()
        let matching = query.isEmpty ? lines : lines.filter { $0.text.lowercased().contains(query) }
        return Array(matching.suffix(500))
    }

    func toggle(_ line: LogLine) {
        if selected.contains(line.id) { selected.remove(line.id) } else { selected.insert(line.id) }
    }

    func copySelection() {
        let text = lines.filter { selected.contains($0.id) }.map(\.text).joined(separator: "\n")
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

struct LogView: View {
    @Environment(AppModel.self) private var model
    var site: Site
    var kind: LogKind
    @State private var log = LogViewModel()
    @State private var copied = false

    /// The log Patchy reports for the site.
    private var file: URL? {
        (kind == .errors ? site.errorLog : site.accessLog).map { URL(fileURLWithPath: $0) }
    }

    var body: some View {
        let rows = log.visible
        VStack(alignment: .leading, spacing: 0) {
            Divider()
            controls
            if !model.serverRunning {
                Text("The server is stopped. New lines will appear once it’s running again.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 8)
            }
            Divider()
            if rows.isEmpty {
                emptyState
            } else {
                lineList(rows)
            }
        }
        .padding(.top, 14)
        .task(id: "\(site.address)|\(kind.rawValue)") {
            if let file { log.follow(file) }
        }
        .onDisappear { log.stop() }
    }

    private var controls: some View {
        @Bindable var log = log
        return HStack(spacing: 8) {
            Button {
                log.toggleLive()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: log.live ? "circle.fill" : "pause.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(log.live ? Theme.green : Theme.grey)
                    Text(log.live ? "Live" : "Paused")
                }
            }
            .help(log.live ? "Pause live updates" : "Resume live updates")

            TextField("Filter lines", text: $log.filter)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
                .accessibilityLabel("Filter log lines")

            Spacer()

            Button(copyTitle) {
                log.copySelection()
                copied = true
                Task {
                    try? await Task.sleep(for: .milliseconds(1400))
                    copied = false
                }
            }
            .disabled(log.selected.isEmpty)
            .help("Click lines to select them, then copy")

            Button("Clear") { log.clear() }
                .help("Clear what’s shown here. The log file isn’t changed.")

            Button("Reveal Log File") {
                if let file { NSWorkspace.shared.activateFileViewerSelecting([file]) }
            }
            .disabled(file.map { !FileManager.default.fileExists(atPath: $0.path) } ?? true)
        }
        .controlSize(.small)
        .padding(.leading, 28)
        .padding(.trailing, 16)
        .padding(.vertical, 8)
    }

    private var copyTitle: String {
        if copied { return String(localized: "Copied") }
        if log.selected.isEmpty { return String(localized: "Copy") }
        return Phrases.copyLines(log.selected.count)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text(emptyTitle).fontWeight(.semibold)
            Text(emptyText)
                .font(.system(size: 12))
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 320)
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.logBackground)
    }

    private var emptyTitle: String {
        if !log.lines.isEmpty { return String(localized: "No matching lines") }
        return kind == .errors ? String(localized: "No errors yet") : String(localized: "No visits yet")
    }

    private var emptyText: String {
        if !log.lines.isEmpty {
            return kind == .errors
                ? String(localized: "Nothing in the errors log contains “\(log.filter)”.")
                : String(localized: "Nothing in the visits log contains “\(log.filter)”.")
        }
        return kind == .errors
            ? String(localized: "When PHP or the server reports a problem with this site, it shows up here.")
            : String(localized: "Open the site in your browser and each page request will show up here.")
    }

    private func lineList(_ rows: [LogLine]) -> some View {
        ScrollViewReader { proxy in
            ScrollView([.vertical, .horizontal]) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(rows) { line in
                        Text(line.text)
                            .font(.system(size: 11.5, design: .monospaced))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .foregroundStyle(line.isBad ? Theme.redText : Color.primary)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(log.selected.contains(line.id) ? Theme.accentSoft : Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture { log.toggle(line) }
                            .accessibilityAddTraits(log.selected.contains(line.id) ? .isSelected : [])
                            .id(line.id)
                    }
                }
                .padding(.vertical, 6)
            }
            .background(Theme.logBackground)
            // Log lines are Apache's English output; they read left to right in every language.
            .environment(\.layoutDirection, .leftToRight)
            .onChange(of: rows.last?.id, initial: true) { _, last in
                if log.live, let last { proxy.scrollTo(last, anchor: .bottomLeading) }
            }
        }
    }
}
