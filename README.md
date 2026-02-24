# Polisher

macOS menu bar app that polishes your text using AI.

## Install

```bash
brew install --cask Triple-Whale/tap/polisher
```

## Setup

1. Open Polisher from Applications (wand icon appears in menu bar)
2. Click the wand icon > **Settings** > **API Keys**
3. Add your API key (click "Get API Key" for the link)
4. Choose your provider in the **Provider** tab (Claude, OpenAI, or Gemini)

## Usage

Two modes:

**Clipboard Mode** (`Cmd+B`) - Copy text first, press the shortcut, paste the improved text.

**Replace Mode** (`Cmd+``)  - Select text in any app, press the shortcut, and it gets polished in-place. Requires Accessibility permission (you'll be prompted on first use).

A floating "Polishing..." indicator appears near your cursor while processing.

## Settings

**General** - Enable/disable shortcuts, customize key combinations, toggle launch at login, edit the system prompt that controls how the AI improves your text.

**API Keys** - Add keys for Claude, OpenAI, or Gemini. Each has a "Get API Key" link to the provider's console.

**Provider** - Choose your AI provider and model. Supports all current models including GPT-5.2, Claude Sonnet 4.6, Gemini 2.5 Pro, and more.

**History** - Browse and search your last 20 improvements. Click to expand and see original vs improved text.

**Logs** - Real-time debug view with level filtering (Info, Success, Error, Debug), search, and copy to clipboard.

## Features

- 3 AI providers with all current models
- Editable system prompt
- Clipboard mode and replace-in-place mode
- Floating HUD loading indicator near cursor
- History with search
- Debug logs
- Configurable shortcuts
- Launch at login

## Build from source

```bash
git clone https://github.com/Triple-Whale/Polisher.git
cd Polisher
bash build.sh
cp -r build/Polisher.app /Applications/
```

## License

Internal tool by [Triple Whale](https://triplewhale.com). Created by Chezi Hoyzer.
