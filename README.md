# Tyyli app skeleton

This branch contains a minimal mobile test view for Tyyli's local wardrobe
storage flow. A user can take photos, choose multiple photos from the device
library, or provide an image URL. Each image is copied into the app's private
file storage, while its clothing record and Claude-generated styling metadata
are stored in an on-device SQLite database.

The data survives app restarts on the same device. Removing an item deletes
both its SQLite record and its app-owned image file. Uninstalling the app also
removes this local data.

## App structure (prototype skeleton)

The UI follows the Figma prototype (Home, Outfit Picks, Closet, History). On
first launch it shows the style quiz. The bottom bar has Home, Closet, a round
center button that opens the stylist chat, History, and Profile.

```
main.jac                  entry point -> screens/AppShell
screens/
  AppShell.jac            loads data, onboarding gate, tab + page switching
  HomeScreen.jac          weather, today's schedule, AI outfit picks, stylist shortcut
  ClosetScreen.jac        search + category grid, "Add new item" panel, item detail
  OutfitsScreen.jac       Outfit Picks: sticker board, style score, swaps, Wearing Today
  HistoryScreen.jac       outfits marked "Wearing Today", newest first
  WeekOutfitScreen.jac    one outfit per day for 7 days (linked from Outfit Picks)
  CalendarScreen.jac      this week's events and their formality
  ChatScreen.jac          stylist chat
  ProfileScreen.jac       style profile from the quiz, link to the storage test
components/               StyleProfileOnboarding, TabBar, OutfitCollage (sticker board), OutfitCard, ...
services/                 app logic the screens call (runs on the device)
  weather_service.jac     Open-Meteo weather using the device location
  calendar_service.jac    PLACEHOLDER sample events (Google Calendar later)
  outfit_service.jac      prepares and displays outfit recommendations
  ai_outfit_service.jac   builds the recommendation context and validates AI results
  chat_service.jac        PLACEHOLDER canned replies (AI later)
  wardrobe_actions.jac    add / analyze / delete closet items
  history_store.jac       outfit history saved on the device (AsyncStorage)
outfit_ai.jac             server-side Claude request, prompt, and response schema
models.jac                WeatherInfo, CalendarEvent, Outfit, ChatMessage, HistoryEntry
storage.jac               StyleProfile, ClothingItem + on-device persistence
ui/kit.jac                design tokens and the shared stylesheet
```

- **To restyle:** edit the tokens and styles in `ui/kit.jac`. Screens only use
  those names.
- **To connect a real service:** replace the body of the matching
  `services/*.jac` function and keep its return type. Screens don't change.
- The outfit engine asks Claude to evaluate clothing metadata against weather,
  calendar formality, style preferences, season, rain protection, and color
  compatibility. Google Calendar can replace the sample event provider later
  without changing the recommendation interface.
- An outfit has the user's own clothing photos, a style name, match reasons,
  a confidence score, and an explanation (see `Outfit` in `models.jac`).
- `services.*` is pinned to the client in `jac.toml` (`[placement.pins]`), so
  these helpers run on the device and are not server endpoints.

## AI outfit recommendation

The outfit picker uses Claude as the decision-making stylist rather than using
a fixed rule-based score. The app sends structured text metadata to the Jac
server; the Anthropic API key stays on the server and is never included in the
mobile bundle.

### Information considered

- Closet metadata: item ID, name, category, colors, style tags, occasions,
  seasons, warmth, and available visual details
- Style profile: preferred styles and colors, common occasions, body-shape
  notes, sizes, shopping section, and saved inspiration
- Today's weather: temperature, conditions, and precipitation chance
- Today's schedule: every event plus its time, kind, and formality; events
  marked as major receive their own recommendation
- The previous seven days of outfit history, so recently worn pieces can be
  avoided when the closet has a suitable alternative

### Recommendation behavior

1. Claude creates one versatile `all_day` outfit that works across the full
   day.
2. Claude also creates one focused outfit for each major calendar event. If
   there are no major events, only the all-day outfit is requested.
3. Each look must use exact IDs from the user's closet and contain either a
   Dress, or both a Top and Bottom. Outerwear is added when the weather needs
   it, and Shoes are included when available.
4. Claude evaluates color harmony, silhouette and proportions, mood, weather,
   schedule practicality, user preferences, and recent repetition. It returns
   a holistic Style Score from 0 to 100 plus separate explanations for color,
   mood, weather, plans, and personal fit.
5. Regenerate supplies a variation number so Claude can propose a different
   valid combination.

The app validates every response before displaying it. Unknown item IDs,
duplicate categories, and incomplete outfits are rejected. Pieces may be
reused across recommendations, but two looks cannot contain the exact same
complete set of items. If Claude omits a required look, returns an invalid
look, or repeats a complete set, the service makes up to three correction
requests for the missing recommendation instead of silently removing it.

Google Calendar is not required by the recommendation interface. The current
event provider can later be replaced with Google Calendar read-only data while
keeping the same recommendation flow.

## Requirements

- Jac `0.37.23` or newer
- Expo Go for SDK 58, an iOS simulator, or an Android emulator
- An Anthropic API key for Claude outfit recommendations and clothing metadata
- For a physical phone, the phone and development computer must be on the
  same local network

Do not commit a real Anthropic API key. For development, copy `.env.example` to
`.env` (gitignored) and put your key there. The server reads `.env` from the
folder it is started in; a key exported in the shell takes precedence.

```bash
cp .env.example .env   # then edit ANTHROPIC_API_KEY in .env
```

## First-time setup

```bash
git pull
jac setup
```

`jac setup` creates the ignored Expo project under `.jac/mobile-rn` and
installs the native dependencies declared in `jac.toml`.

Jac currently scaffolds an SDK 57 package before applying project-specific
dependencies. The first `./scripts/dev_mobile.sh` run upgrades that generated
package to SDK 58 so it matches the current Expo Go app. Later runs reuse the
installed SDK 58 dependencies.

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
3. Wait for the Claude metadata or tap **Analyze** again if Claude returns a
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
