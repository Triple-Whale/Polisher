import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsManager
    @EnvironmentObject var aiManager: AIManager

    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("General", systemImage: "gear") }
            APIKeysTab()
                .tabItem { Label("API Keys", systemImage: "key") }
            ProviderTab()
                .tabItem { Label("Provider", systemImage: "cpu") }
        }
        .frame(width: 450, height: 300)
        .environmentObject(settings)
        .environmentObject(aiManager)
    }
}

struct GeneralTab: View {
    @EnvironmentObject var settings: SettingsManager

    var body: some View {
        Form {
            Toggle("Auto-replace selected text", isOn: $settings.autoReplace)
            Text("When off, improved text is copied to clipboard with a notification.")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            Toggle("Global hotkey (Cmd+Option+I)", isOn: $settings.hotKeyEnabled)
            Text("Capture selected text and improve it with a keyboard shortcut.")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            Toggle("Launch at login", isOn: $settings.launchAtLogin)
        }
        .padding()
    }
}

struct APIKeysTab: View {
    @EnvironmentObject var settings: SettingsManager
    @EnvironmentObject var aiManager: AIManager
    @State private var claudeKey: String = ""
    @State private var openAIKey: String = ""
    @State private var showClaudeKey = false
    @State private var showOpenAIKey = false

    var body: some View {
        Form {
            VStack(alignment: .leading, spacing: 8) {
                Text("Claude (Anthropic)")
                    .font(.headline)
                HStack {
                    if showClaudeKey {
                        TextField("sk-ant-...", text: $claudeKey)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("sk-ant-...", text: $claudeKey)
                            .textFieldStyle(.roundedBorder)
                    }
                    Button(showClaudeKey ? "Hide" : "Show") {
                        showClaudeKey.toggle()
                    }
                    .frame(width: 50)
                }
                HStack {
                    if !settings.claudeAPIKey.isEmpty {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Key configured")
                            .font(.caption)
                    }
                    Spacer()
                    Button("Save") {
                        settings.claudeAPIKey = claudeKey
                        aiManager.configure(with: settings)
                    }
                    .disabled(claudeKey.isEmpty)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("OpenAI")
                    .font(.headline)
                HStack {
                    if showOpenAIKey {
                        TextField("sk-...", text: $openAIKey)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("sk-...", text: $openAIKey)
                            .textFieldStyle(.roundedBorder)
                    }
                    Button(showOpenAIKey ? "Hide" : "Show") {
                        showOpenAIKey.toggle()
                    }
                    .frame(width: 50)
                }
                HStack {
                    if !settings.openAIAPIKey.isEmpty {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Key configured")
                            .font(.caption)
                    }
                    Spacer()
                    Button("Save") {
                        settings.openAIAPIKey = openAIKey
                        aiManager.configure(with: settings)
                    }
                    .disabled(openAIKey.isEmpty)
                }
            }
        }
        .padding()
        .onAppear {
            claudeKey = settings.claudeAPIKey
            openAIKey = settings.openAIAPIKey
        }
    }
}

struct ProviderTab: View {
    @EnvironmentObject var settings: SettingsManager
    @EnvironmentObject var aiManager: AIManager

    var body: some View {
        Form {
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

            VStack(alignment: .leading) {
                Text("Status")
                    .font(.headline)
                let hasKey = settings.selectedProvider == .claude
                    ? !settings.claudeAPIKey.isEmpty
                    : !settings.openAIAPIKey.isEmpty
                HStack {
                    Image(systemName: hasKey ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(hasKey ? .green : .red)
                    Text(hasKey ? "API key configured" : "No API key - set in API Keys tab")
                }
            }
        }
        .padding()
    }
}
