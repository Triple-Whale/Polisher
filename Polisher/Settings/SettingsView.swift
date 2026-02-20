import SwiftUI
import Carbon

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsManager
    @EnvironmentObject var aiManager: AIManager
    @EnvironmentObject var historyManager: HistoryManager
    @ObservedObject var logManager = LogManager.shared

    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("General", systemImage: "gear") }
            APIKeysTab()
                .tabItem { Label("API Keys", systemImage: "key") }
            ProviderTab()
                .tabItem { Label("Provider", systemImage: "cpu") }
            HistoryTab()
                .tabItem { Label("History", systemImage: "clock") }
            LogsTab()
                .tabItem { Label("Logs", systemImage: "doc.text") }
            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 500, height: 420)
        .environmentObject(settings)
        .environmentObject(aiManager)
        .environmentObject(historyManager)
    }
}

struct GeneralTab: View {
    @EnvironmentObject var settings: SettingsManager
    @ObservedObject var promptManager = SystemPromptManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Global hotkey enabled", isOn: $settings.hotKeyEnabled)

            HStack {
                Text("Shortcut:")
                ShortcutRecorderView(
                    keyCode: $settings.hotKeyCode,
                    modifiers: $settings.hotKeyModifiers
                )
                .frame(width: 140, height: 24)
            }
            Text("Click the field above and press a new key combination.")
                .font(.caption)
                .foregroundColor(.secondary)

            Toggle("Launch at login", isOn: $settings.launchAtLogin)

            Divider()

            HStack {
                Text("System Prompt")
                    .font(.headline)
                Spacer()
                Button("Reset") {
                    promptManager.resetToDefault()
                }
                .font(.caption)
                .disabled(promptManager.customPrompt == SystemPromptManager.defaultPrompt)
            }

            TextEditor(text: $promptManager.customPrompt)
                .font(.system(size: 11))
                .frame(maxHeight: .infinity)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
        }
        .padding()
    }
}

struct ShortcutRecorderView: NSViewRepresentable {
    @Binding var keyCode: UInt32
    @Binding var modifiers: UInt32

    func makeNSView(context: Context) -> ShortcutRecorderNSView {
        let view = ShortcutRecorderNSView()
        view.keyCode = keyCode
        view.modifiers = modifiers
        view.onShortcutChanged = { newKeyCode, newModifiers in
            keyCode = newKeyCode
            modifiers = newModifiers
        }
        return view
    }

    func updateNSView(_ nsView: ShortcutRecorderNSView, context: Context) {
        if !nsView.isRecording {
            nsView.keyCode = keyCode
            nsView.modifiers = modifiers
            nsView.updateDisplay()
        }
    }
}

class ShortcutRecorderNSView: NSView {
    var keyCode: UInt32 = 34
    var modifiers: UInt32 = UInt32(cmdKey | optionKey)
    var isRecording = false
    var onShortcutChanged: ((UInt32, UInt32) -> Void)?

    private let label = NSTextField(labelWithString: "")
    private var localMonitor: Any?

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 5
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor

        label.isEditable = false
        label.isBezeled = false
        label.drawsBackground = false
        label.alignment = .center
        label.font = .systemFont(ofSize: 13)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -4),
        ])

        updateDisplay()
    }

    func updateDisplay() {
        if isRecording {
            label.stringValue = "Press shortcut..."
            label.textColor = .placeholderTextColor
            layer?.borderColor = NSColor.controlAccentColor.cgColor
            layer?.borderWidth = 2
        } else {
            label.stringValue = SettingsManager.shortcutString(keyCode: keyCode, modifiers: modifiers)
            label.textColor = .labelColor
            layer?.borderColor = NSColor.separatorColor.cgColor
            layer?.borderWidth = 1
        }
    }

    override func mouseDown(with event: NSEvent) {
        if isRecording {
            stopRecording()
            return
        }
        startRecording()
    }

    private func startRecording() {
        isRecording = true
        updateDisplay()
        window?.makeFirstResponder(self)

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        updateDisplay()
    }

    private func handleKeyEvent(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if event.keyCode == 53 {
            stopRecording()
            return
        }

        guard !flags.isEmpty else { return }

        var carbonMods: UInt32 = 0
        if flags.contains(.command) { carbonMods |= UInt32(cmdKey) }
        if flags.contains(.option) { carbonMods |= UInt32(optionKey) }
        if flags.contains(.control) { carbonMods |= UInt32(controlKey) }
        if flags.contains(.shift) { carbonMods |= UInt32(shiftKey) }

        keyCode = UInt32(event.keyCode)
        modifiers = carbonMods
        onShortcutChanged?(keyCode, modifiers)
        stopRecording()
    }

    override var acceptsFirstResponder: Bool { true }
}

struct HistoryTab: View {
    @EnvironmentObject var historyManager: HistoryManager
    @State private var searchText = ""
    @State private var expandedEntryId: UUID?

    private var filteredEntries: [HistoryEntry] {
        if searchText.isEmpty { return historyManager.entries }
        let query = searchText.lowercased()
        return historyManager.entries.filter {
            $0.originalText.lowercased().contains(query) ||
            $0.improvedText.lowercased().contains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search history...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            if filteredEntries.isEmpty {
                Spacer()
                Text(historyManager.entries.isEmpty ? "No history yet" : "No matches")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                List {
                    ForEach(filteredEntries) { entry in
                        HistoryRowView(
                            entry: entry,
                            isExpanded: expandedEntryId == entry.id,
                            onToggle: {
                                withAnimation {
                                    expandedEntryId = expandedEntryId == entry.id ? nil : entry.id
                                }
                            }
                        )
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let entry = filteredEntries[index]
                            historyManager.deleteEntry(id: entry.id)
                        }
                    }
                }
            }

            Divider()

            HStack {
                Text("\(historyManager.entries.count) entries")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Clear All") {
                    historyManager.clearAll()
                    expandedEntryId = nil
                }
                .disabled(historyManager.entries.isEmpty)
            }
            .padding(8)
        }
    }
}

struct HistoryRowView: View {
    let entry: HistoryEntry
    let isExpanded: Bool
    let onToggle: () -> Void

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Self.dateFormatter.string(from: entry.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(entry.improvedText)
                        .lineLimit(isExpanded ? nil : 1)
                        .font(.body)
                }
                Spacer()
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(entry.improvedText, forType: .string)
                }) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.plain)
                .help("Copy improved text")
            }
            .contentShape(Rectangle())
            .onTapGesture { onToggle() }

            if isExpanded {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Original:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(entry.originalText)
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                    Text("Improved:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                    Text(entry.improvedText)
                        .font(.callout)
                        .textSelection(.enabled)
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
}

struct APIKeysTab: View {
    @EnvironmentObject var settings: SettingsManager
    @EnvironmentObject var aiManager: AIManager
    @State private var claudeKey: String = ""
    @State private var openAIKey: String = ""
    @State private var geminiKey: String = ""
    @State private var showClaudeKey = false
    @State private var showOpenAIKey = false
    @State private var showGeminiKey = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            apiKeySection(
                title: "Claude (Anthropic)",
                linkTitle: "Get API Key",
                linkURL: "https://console.anthropic.com/settings/keys",
                placeholder: "sk-ant-...",
                key: $claudeKey,
                showKey: $showClaudeKey,
                isConfigured: !settings.claudeAPIKey.isEmpty,
                onSave: {
                    settings.claudeAPIKey = claudeKey
                    aiManager.configure(with: settings)
                }
            )

            Divider()

            apiKeySection(
                title: "OpenAI",
                linkTitle: "Get API Key",
                linkURL: "https://platform.openai.com/api-keys",
                placeholder: "sk-...",
                key: $openAIKey,
                showKey: $showOpenAIKey,
                isConfigured: !settings.openAIAPIKey.isEmpty,
                onSave: {
                    settings.openAIAPIKey = openAIKey
                    aiManager.configure(with: settings)
                }
            )

            Divider()

            apiKeySection(
                title: "Gemini (Google)",
                linkTitle: "Get API Key",
                linkURL: "https://aistudio.google.com/apikey",
                placeholder: "AIza...",
                key: $geminiKey,
                showKey: $showGeminiKey,
                isConfigured: !settings.geminiAPIKey.isEmpty,
                onSave: {
                    settings.geminiAPIKey = geminiKey
                    aiManager.configure(with: settings)
                }
            )

            Spacer()
        }
        .padding()
        .onAppear {
            claudeKey = settings.claudeAPIKey
            openAIKey = settings.openAIAPIKey
            geminiKey = settings.geminiAPIKey
        }
    }

    @ViewBuilder
    private func apiKeySection(
        title: String, linkTitle: String, linkURL: String,
        placeholder: String, key: Binding<String>, showKey: Binding<Bool>,
        isConfigured: Bool, onSave: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.headline)
                Spacer()
                Link(linkTitle, destination: URL(string: linkURL)!).font(.caption)
            }
            HStack(spacing: 6) {
                if showKey.wrappedValue {
                    TextField(placeholder, text: key).textFieldStyle(.roundedBorder)
                } else {
                    SecureField(placeholder, text: key).textFieldStyle(.roundedBorder)
                }
                Button(showKey.wrappedValue ? "Hide" : "Show") { showKey.wrappedValue.toggle() }
                    .frame(width: 50)
                Button("Save", action: onSave).disabled(key.wrappedValue.isEmpty)
            }
            if isConfigured {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green).font(.caption)
                    Text("Key configured").font(.caption).foregroundColor(.secondary)
                }
            }
        }
    }
}

struct ProviderTab: View {
    @EnvironmentObject var settings: SettingsManager
    @EnvironmentObject var aiManager: AIManager

    private var hasKey: Bool {
        switch settings.selectedProvider {
        case .claude: return !settings.claudeAPIKey.isEmpty
        case .openai: return !settings.openAIAPIKey.isEmpty
        case .gemini: return !settings.geminiAPIKey.isEmpty
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Provider", selection: $settings.selectedProvider) {
                ForEach(AIProviderType.allCases, id: \.self) { provider in
                    Text(provider.rawValue).tag(provider)
                }
            }
            .onChange(of: settings.selectedProvider) { _, newProvider in
                settings.selectedModel = settings.defaultModel(for: newProvider)
                aiManager.configure(with: settings)
            }

            Picker("Model", selection: $settings.selectedModel) {
                ForEach(settings.modelsForProvider(settings.selectedProvider), id: \.self) { model in
                    Text(model).tag(model)
                }
            }
            .onChange(of: settings.selectedModel) { _, _ in
                aiManager.configure(with: settings)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Status")
                    .font(.headline)
                HStack(spacing: 4) {
                    Image(systemName: hasKey ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(hasKey ? .green : .red)
                    Text(hasKey ? "API key configured" : "No API key - set in API Keys tab")
                }
            }

            Spacer()
        }
        .padding()
    }
}

struct LogsTab: View {
    @ObservedObject var logManager = LogManager.shared
    @State private var filterLevel: LogLevel? = nil
    @State private var searchText = ""
    @State private var autoScroll = true

    private var filteredEntries: [LogEntry] {
        logManager.entries.filter { entry in
            let matchesLevel = filterLevel == nil || entry.level == filterLevel
            let matchesSearch = searchText.isEmpty ||
                entry.message.localizedCaseInsensitiveContains(searchText) ||
                entry.category.localizedCaseInsensitiveContains(searchText)
            return matchesLevel && matchesSearch
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.caption)
                TextField("Filter logs...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))

                Divider().frame(height: 16)

                ForEach([nil] + LogLevel.allCases.map { Optional($0) }, id: \.self) { level in
                    Button(action: { filterLevel = level }) {
                        Text(level?.rawValue ?? "All")
                            .font(.system(size: 10, weight: filterLevel == level ? .bold : .regular))
                            .foregroundColor(filterLevel == level ? levelColor(level) : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            if filteredEntries.isEmpty {
                Spacer()
                VStack(spacing: 4) {
                    Image(systemName: "doc.text")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text(logManager.entries.isEmpty ? "No logs yet" : "No matching logs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if logManager.entries.isEmpty {
                        Text("Trigger a shortcut to see activity here")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    List {
                        ForEach(filteredEntries) { entry in
                            LogRowView(entry: entry)
                                .id(entry.id)
                                .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                        }
                    }
                    .listStyle(.plain)
                    .font(.system(size: 11, design: .monospaced))
                    .onChange(of: logManager.entries.count) { _, _ in
                        if autoScroll, let last = filteredEntries.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            HStack(spacing: 10) {
                Text("\(filteredEntries.count)/\(logManager.entries.count) entries")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Spacer()

                Toggle("Auto-scroll", isOn: $autoScroll)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 10))
                    .controlSize(.small)

                Button(action: copyLogs) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .help("Copy logs to clipboard")

                Button(action: { logManager.clear() }) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .help("Clear all logs")
                .disabled(logManager.entries.isEmpty)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
        }
    }

    private func copyLogs() {
        let text = filteredEntries.map { $0.exportLine }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func levelColor(_ level: LogLevel?) -> Color {
        guard let level else { return .primary }
        switch level {
        case .info: return .blue
        case .success: return .green
        case .error: return .red
        case .debug: return .secondary
        }
    }
}

struct LogRowView: View {
    let entry: LogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(entry.formattedTime)
                .foregroundColor(.secondary)
                .frame(width: 72, alignment: .leading)

            Text(entry.level.symbol)
                .foregroundColor(color)
                .frame(width: 12)

            Text(entry.category)
                .foregroundColor(.secondary)
                .frame(width: 52, alignment: .leading)
                .lineLimit(1)

            Text(entry.message)
                .foregroundColor(color)
                .lineLimit(3)
                .textSelection(.enabled)
        }
    }

    private var color: Color {
        switch entry.level {
        case .info: return .primary
        case .success: return .green
        case .error: return .red
        case .debug: return .secondary
        }
    }
}

struct AboutTab: View {
    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    private let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "wand.and.stars")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("Polisher")
                .font(.title)
                .fontWeight(.bold)

            Text("v\(version) (build \(build))")
                .font(.callout)
                .foregroundColor(.secondary)

            Text("AI-powered text polishing from your menu bar")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()
                .frame(width: 200)

            VStack(spacing: 4) {
                Text("Created by Chezi Hoyzer")
                    .font(.body)
                Link("Triple Whale", destination: URL(string: "https://triplewhale.com")!)
                    .font(.body)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
