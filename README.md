# Polisher

macOS menu bar app that polishes your text using AI. Copy, shortcut, paste.

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

1. Copy any text (`Cmd+C`)
2. Press `Cmd+Option+I`
3. Paste the improved text (`Cmd+V`)

The menu bar shows "Polishing..." while working and "Done! Paste to use." when ready.

## Features

- **3 AI providers** - Claude, OpenAI, Gemini
- **Editable system prompt** - customize how your text gets improved
- **History** - browse and search your last 20 improvements
- **Logs** - debug tab with level filtering, search, and copy
- **Custom shortcut** - change the keyboard shortcut in settings
- **Menu bar feedback** - loading icon and status messages

## Build from source

```bash
git clone https://github.com/Triple-Whale/Polisher.git
cd Polisher
bash build.sh
cp -r build/Polisher.app /Applications/
```

## License

Internal tool by [Triple Whale](https://triplewhale.com). Created by Chezi Hoyzer.
