# Tyyli local wardrobe demo

This branch contains a minimal mobile test view for Tyyli's local wardrobe
storage flow. A user can take photos, choose multiple photos from the device
library, or provide an image URL. Each image is copied into the app's private
file storage, while its clothing record and Gemini-generated styling metadata
are stored in an on-device SQLite database.

The data survives app restarts on the same device. Removing an item deletes
both its SQLite record and its app-owned image file. Uninstalling the app also
removes this local data.

## Requirements

- Jac `0.37.23` or newer
- Expo Go, an iOS simulator, or an Android emulator
- A Gemini API key created in Google AI Studio
- For a physical phone, the phone and development computer must be on the
  same local network

Do not commit a real Gemini API key. The server reads it from the shell that
starts Jac.

## First-time setup

```bash
git checkout local-storage-feature
jac setup
```

`jac setup` creates the ignored Expo project under `.jac/mobile-rn` and
installs the native dependencies declared in `jac.toml`.

## Run the native app

Export the API key and start the app from the same terminal:

```bash
export GEMINI_API_KEY="your-new-google-ai-studio-key"
jac run --dev main.jac
```

Jac starts Metro and the Jac API server together, detects the computer's LAN
address, and injects that address into the Expo development app. Do not add a
personal IP address to `main.jac`.

- Scan the QR code with Expo Go on a physical phone.
- Press `i` in the Jac/Expo terminal to open the iOS simulator.
- Press `a` to open an available Android emulator.

If LAN detection chooses the wrong interface, stop the process and set the
host explicitly before restarting:

```bash
export JAC_RN_DEV_HOST="your-computer-lan-ip"
jac run --dev main.jac
```

## Test the storage flow

1. Add one or more images using **Take photo**, **From gallery**, or an image
   URL.
2. Confirm every item appears in **My closet** with an `App storage:` path.
3. Wait for the Gemini metadata or tap **Analyze** again if Gemini returns a
   temporary `503` capacity error.
4. Close and reopen the app. The saved items should still appear.
5. Tap **Delete** and confirm the item is removed.

## Browser preview

The web target is useful for checking layout and the basic data flow:

```bash
jac run --dev --platform web main.jac
```

Native file storage and SQLite are used only on iOS and Android. The browser
adapter uses browser storage and does not prove native persistence.

## Troubleshooting the API server

The normal `jac run --dev main.jac` command starts the API server automatically.
The terminal should print an API URL, and opening `<API URL>/docs` from the
phone should return the API documentation.

If the automatic API child process does not start, keep Metro running and use
a second terminal. Use the same API port printed by the development command:

```bash
cd /path/to/tyyli
export GEMINI_API_KEY="your-new-google-ai-studio-key"
jac run --no-takeover --serve --no-client --port 8000 ai_server.jac
```

Change `8000` if the development command printed a different API port.
