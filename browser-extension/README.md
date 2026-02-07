# ClawBox Browser Extension

Browser extension for ClawBox - AI-Native Secret Manager.

## Features

- 🔐 Quick access to secrets from browser
- 🔑 Auto-fill passwords and tokens
- ⌨️ Keyboard shortcut (Cmd/Ctrl+Shift+L)
- 🔍 Search secrets
- ➕ Add new secrets

## Installation

### Chrome / Edge / Brave

1. Open `chrome://extensions/`
2. Enable "Developer mode"
3. Click "Load unpacked"
4. Select the `browser-extension` folder

### Firefox

1. Open `about:debugging#/runtime/this-firefox`
2. Click "Load Temporary Add-on"
3. Select `manifest.json`

## Usage

1. Click the ClawBox icon in toolbar
2. Enter master password to unlock
3. Click on a secret to auto-fill
4. Use 📋 to copy to clipboard

### Keyboard Shortcut

- **Windows/Linux**: `Ctrl+Shift+L`
- **macOS**: `Cmd+Shift+L`

## Development

```bash
# Watch for changes
npm run watch

# Build for production
npm run build
```

## Architecture

```
browser-extension/
├── manifest.json      # Extension config
├── popup/             # Popup UI
│   ├── popup.html
│   ├── popup.css
│   └── popup.js
├── src/
│   ├── background.js  # Service worker
│   ├── content.js     # Page injection
│   └── content.css
└── icons/             # Extension icons
```

## Requirements

- ClawBox CLI installed
- Chrome 88+ / Firefox 109+ / Edge 88+

## License

MIT © Harris Han
