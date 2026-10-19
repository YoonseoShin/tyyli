# Tyyli app skeleton

This branch contains a minimal mobile test view for Tyyli's local wardrobe
storage flow. A user can take photos, choose multiple photos from the device
library, or provide an image URL. Each image is copied into the app's private
file storage, while its clothing record and Gemini-generated styling metadata
are stored in an on-device SQLite database.

The data survives app restarts on the same device. Removing an item deletes
both its SQLite record and its app-owned image file. Uninstalling the app also
removes this local data.

## App structure (prototype skeleton)

The app is a minimal, unstyled skeleton so UI design can be layered on later.
On first launch it shows the style quiz; after that it opens to five tabs.

```
main.jac                  entry point -> screens/AppShell
screens/
  AppShell.jac            loads data, onboarding gate, tab + page switching
  HomeScreen.jac          today's weather, outfit, plans, closet summary
  ClosetScreen.jac        add photos (camera / gallery / URL), grid, item detail
  OutfitsScreen.jac       Today / This week toggle
  TodayOutfitScreen.jac   today's outfit with each piece
  WeekOutfitScreen.jac    one outfit per day for 7 days
  CalendarScreen.jac      this week's events and their formality
  ChatScreen.jac          stylist chat
  ProfileScreen.jac       style profile from the quiz, link to the storage test
components/               StyleProfileOnboarding, TabBar, OutfitCard, WeatherCard, EventRow
services/                 app logic the screens call (runs on the device)
  weather_service.jac     PLACEHOLDER sample weather
  calendar_service.jac    PLACEHOLDER sample events (Google Calendar later)
  outfit_service.jac      PLACEHOLDER rule-based outfit picker (AI later)
  chat_service.jac        PLACEHOLDER canned replies (AI later)
  wardrobe_actions.jac    add / analyze / delete closet items
models.jac                WeatherInfo, CalendarEvent, Outfit, ChatMessage
storage.jac               StyleProfile, ClothingItem + on-device persistence
ui/kit.jac                design tokens and the shared stylesheet
```

- **To restyle:** edit the tokens and styles in `ui/kit.jac`. Screens only use
  those names.
- **To connect a real service:** replace the body of the matching
  `services/*.jac` function and keep its return type. Screens don't change.
- An outfit has the user's own clothing photos, a style name, a reason, and a
  description (see `Outfit` in `models.jac`).
- `services.*` is pinned to the client in `jac.toml` (`[placement.pins]`), so
  these helpers run on the device and are not server endpoints.

## Requirements

- Jac `0.37.23` or newer
- Expo Go, an iOS simulator, or an Android emulator
- A Gemini API key created in Google AI Studio
- For a physical phone, the phone and development computer must be on the
  same local network

Do not commit a real Gemini API key. For development, copy `.env.example` to
`.env` (gitignored) and put your key there. The server reads `.env` from the
folder it is started in; a key exported in the shell takes precedence.

```bash
cp .env.example .env   # then edit GEMINI_API_KEY in .env
```

## First-time setup

```bash
git checkout app-skeleton
jac setup
```

`jac setup` creates the ignored Expo project under `.jac/mobile-rn` and
installs the native dependencies declared in `jac.toml`.

## Run the native app

With the key in `.env`, start the API server and Expo together from the
project folder:

```bash
./scripts/dev_mobile.sh
```

The script detects the computer's LAN address, injects it into the generated
Expo app, starts the Jac API server, and then starts Metro. Press `Ctrl+C` once
to stop both processes.

- Scan the QR code with Expo Go on a physical phone.
- Press `i` in the Jac/Expo terminal to open the iOS simulator.
- Press `a` to open an available Android emulator.

If LAN detection chooses the wrong interface, stop the process and set the
host explicitly before restarting:

```bash
export JAC_RN_DEV_HOST="your-computer-lan-ip"
./scripts/dev_mobile.sh
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

Use `./scripts/dev_mobile.sh` for this project. It works around the current Jac
mobile dev-runner issue by starting the API server and Metro separately while
keeping the correct device-visible API URL in the Expo bundle.

If the script reports that port `8000` or `8081` is already in use, find the
old development process:

```bash
lsof -nP -iTCP:8000 -sTCP:LISTEN
lsof -nP -iTCP:8081 -sTCP:LISTEN
```

Stop only the listed stale Jac/Expo process, then run the script again. For a
physical phone, opening the printed API URL with `/docs` in the phone browser
confirms that the phone can reach the Mac.
