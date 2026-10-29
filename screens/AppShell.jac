"""App shell: loads data, gates on onboarding, and switches between screens.

Navigation is plain state: `tab` is the bottom-tab screen and `route` is a
full-screen page opened on top for onboarding.
"""
import from "@jac/mobui" { Keyboard, Platform, Pressable, Text, View }
import from ..components.StyleProfileOnboarding { StyleProfileOnboarding }
import from ..components.TabBar { TabBar }
import from ..models { CalendarEvent, ChatMessage, HistoryEntry, Outfit, WeatherInfo }
import from ..services.ai_outfit_service { request_ai_outfit_recommendations }
import from ..services.calendar_service { events_on, get_week_events, save_week_events }
import from ..services.chat_service { send_chat_message }
import from ..services.dates { date_key }
import from ..services.history_store { delete_history_entry, load_history, save_history_entry }
import from ..services.outfit_pick_store { load_daily_outfit_picks, save_daily_outfit_picks }
import from ..services.outfit_service { build_picks }
import from ..services.weather_service { get_today_weather }
import from ..storage { LocalUserData, StyleProfile, clear_local_data, load_local_data, save_profile }
import from ..ui.kit { ui }
import from .ChatScreen { ChatScreen }
import from .ClosetScreen { ClosetScreen }
import from .HistoryScreen { HistoryScreen }
import from .HomeScreen { HomeScreen }
import from .OutfitsScreen { OutfitsScreen }
import from .ProfileScreen { ProfileScreen }


# Screens that show the bottom nav bar. "outfits" (Outfit Picks) is opened from
# Home rather than the bar, so the bar highlights Home while it is open.
glob TAB_IDS: list[str] = ["home", "closet", "outfits", "chat", "history", "profile"];


def:pub AppShell -> JsxElement {
    has data: LocalUserData = LocalUserData(),
        loaded: bool = False,
        load_error: str = "",
        weather: WeatherInfo | None = None,
        events: list[CalendarEvent] = [],
        tab: str = "home",
        route: str = "",
        messages: list[ChatMessage] = [],
        sending: bool = False,
        regenerating: bool = False,
        outfit_variation: int = 0,
        pick_index: int = 0,
        ai_picks: list[Outfit] = [],
        looks: list[HistoryEntry] = [],
        temperature_unit: str = "F",
        keyboard_height: float = 0.0;
    async def reload {
        try {
            data = await load_local_data();
            temperature_unit = data.profile.temperature_unit if data.profile is not None else "F";
            load_error = "";
        } except Exception as e {
            load_error = "Could not load your data: " + str(e);
        }
        loaded = True;
    }

    # Claude only runs after the user taps Generate or Regenerate.
    async def refresh_recommendations(variation: int) {
        if not build_picks(data.clothes, data.profile, weather, events, variation) { return; }
        load_error = "";
        try {
            generated = await request_ai_outfit_recommendations(data.clothes, data.profile, weather, events, looks, variation);
            if generated {
                ai_picks = generated;
                outfit_variation = variation;
                await save_daily_outfit_picks(date_key(0), variation, generated);
            } else {
                load_error = "Could not generate outfit picks. Try again.";
            }
        } except Exception as e {
            load_error = "Could not generate outfit picks: " + str(e);
        }
    }

    async def load_saved_recommendations {
        saved = await load_daily_outfit_picks(date_key(0));
        ai_picks = saved.outfits;
        outfit_variation = saved.variation;
    }

    async can with entry {
        # While the keyboard is up, the shell shrinks by its height and the tab
        # bar hides, so text inputs on every screen stay visible above it.
        if Platform.OS != "web" {
            show_event = "keyboardWillShow" if Platform.OS == "ios" else "keyboardDidShow";
            hide_event = "keyboardWillHide" if Platform.OS == "ios" else "keyboardDidHide";
            Keyboard.addListener(show_event, lambda (e: any) { keyboard_height = e.endCoordinates.height; });
            Keyboard.addListener(hide_event, lambda (e: any) { keyboard_height = 0.0; });
        }
        await reload();
        try {
            looks = await load_history();
        } except Exception {}
        weather = await get_today_weather();
        events = await get_week_events();
        try {
            await load_saved_recommendations();
        } except Exception {
            ai_picks = [];
            outfit_variation = 0;
        }
    }

    def navigate(target: str) {
        if target in TAB_IDS {
            tab = target;
            route = "";
        } else {
            route = target;
        }
    }

    async def toggle_temperature_unit {
        if data.profile is None { return; }
        profile = data.profile;
        next_unit = "C" if temperature_unit != "C" else "F";
        temperature_unit = next_unit;
        profile.temperature_unit = next_unit;
        await save_profile(profile);
    }

    async def update_today_events(updated: list[CalendarEvent]) {
        today = date_key(0);
        events = [event for event in events if event.date != today] + updated;
        try {
            await save_week_events(events);
            load_error = "";
        } except Exception as e {
            load_error = "Could not save the test schedule: " + str(e);
        }
    }

    # The user wants to fix an earlier message: drop it and everything after it;
    # the chat screen puts its text back into the input box.
    def edit_message(index: int) {
        if sending { return; }
        messages = messages[:index];
    }

    # Developer reset: wipe everything on the device and start from the splash.
    async def reset_app_data {
        await clear_local_data();
        messages = [];
        route = "";
        tab = "home";
        ai_picks = [];
        outfit_variation = 0;
        looks = [];
        await reload();
    }

    def open_pick(index: int) {
        pick_index = index;
        tab = "outfits";
        route = "";
    }

    async def generate_first_outfits {
        if regenerating { return; }
        regenerating = True;
        pick_index = 0;
        try {
            await refresh_recommendations(0);
        } finally {
            regenerating = False;
        }
    }

    async def regenerate_outfits {
        if regenerating { return; }
        regenerating = True;
        next_variation = outfit_variation + 1;
        outfit_variation = next_variation;
        pick_index = 0;
        try {
            await refresh_recommendations(next_variation);
        } finally {
            regenerating = False;
        }
    }

    # "Wearing Today": log the look in History (one entry per day).
    async def wear(outfit: Outfit) {
        entry_today = HistoryEntry(
            entry_id="look-" + date_key(0) + "-" + str(Date.now()),
            date=date_key(0),
            style_name=outfit.style_name,
            clothing_item_ids=outfit.clothing_item_ids,
            event_title=outfit.event_title,
            formality_label=outfit.match_reasons[1] if len(outfit.match_reasons) > 1 else "",
            temperature_f=weather.temperature_f if weather is not None else 0,
            created_at=str(Date.now())
        );
        try {
            looks = await save_history_entry(entry_today);
        } except Exception as e {
            load_error = "Could not save to history: " + str(e);
        }
    }

    async def remove_look(look_id: str) {
        try {
            looks = await delete_history_entry(look_id);
        } except Exception as e {
            load_error = "Could not update history: " + str(e);
        }
    }

    async def finish_onboarding(profile: StyleProfile) {
        data = await save_profile(profile);
        temperature_unit = profile.temperature_unit;
        route = "";
        tab = "home";
    }

    async def send_message(text: str) {
        history = messages + [ChatMessage(role="user", text=text)];
        messages = history;
        sending = True;
        try {
            reply = await send_chat_message(history, data.clothes, data.profile, weather, events);
            messages = history + [reply];
        } except Exception as e {
            messages = history + [ChatMessage(role="assistant", text="Something went wrong: " + str(e))];
        }
        sending = False;
    }

    if not loaded {
        return <View style={[ui.screen, {"alignItems": "center", "justifyContent": "center"}]}>
            <Text style={ui.muted}>Loading...</Text>
        </View>;
    }

    # First launch (no saved profile) or "Redo style quiz".
    if data.profile is None or route == "onboarding" {
        return <StyleProfileOnboarding initial={data.profile} on_finish={lambda (p: StyleProfile) { finish_onboarding(p); }} on_cancel={lambda { route = ""; }}/>;
    }

    today_events = events_on(events, date_key(0));
    picks = ai_picks;
    can_generate = bool(build_picks(data.clothes, data.profile, weather, events, 0));
    unit = temperature_unit;
    # The pieces logged for today, so Outfit Picks can show "Saved to History".
    worn_today = [",".join(sorted(l.clothing_item_ids)) for l in looks if l.date == date_key(0)];

    return <View style={ui.app}>
        {(<Text style={[ui.muted, {"padding": 16}]}>{load_error}</Text>) if load_error else None}
        <View style={ui.flex1}>
            {(<HomeScreen
                weather={weather}
                today_events={today_events}
                picks={picks}
                clothes={data.clothes}
                can_generate={can_generate}
                generating={regenerating}
                on_navigate={lambda (t: str) { navigate(t); }}
                on_open_pick={lambda (i: int) { open_pick(i); }}
                on_generate={lambda { generate_first_outfits(); }}
                on_events_change={lambda (updated: list[CalendarEvent]) { update_today_events(updated); }}
                temperature_unit={unit}
                on_toggle_unit={lambda { toggle_temperature_unit(); }}
            />) if tab == "home" else None}
            {(<ClosetScreen clothes={data.clothes} on_changed={lambda { reload(); }}/>) if tab == "closet" else None}
            {(<OutfitsScreen
                picks={picks}
                selected={pick_index}
                clothes={data.clothes}
                weather={weather}
                temperature_unit={unit}
                worn_today_key={worn_today[0] if worn_today else ""}
                regenerating={regenerating}
                on_select={lambda (i: int) { pick_index = i; }}
                on_regenerate={lambda { regenerate_outfits(); }}
                on_wear={lambda (o: Outfit) { wear(o); }}
                on_back={lambda { navigate("home"); }}
            />) if tab == "outfits" else None}
            {(<ChatScreen messages={messages} sending={sending} clothes={data.clothes} on_send={lambda (t: str) { send_message(t); }} on_edit={lambda (i: int) { edit_message(i); }} keyboard_height={keyboard_height}/>) if tab == "chat" else None}
            {(<HistoryScreen looks={looks} clothes={data.clothes} temperature_unit={unit} on_delete={lambda (look_id: str) { remove_look(look_id); }}/>) if tab == "history" else None}
            {(<ProfileScreen profile={data.profile} on_edit_profile={lambda { route = "onboarding"; }} on_reset={lambda { reset_app_data(); }}/>) if tab == "profile" else None}
        </View>
        {(<TabBar active={"home" if tab == "outfits" else tab} on_select={lambda (t: str) { navigate(t); }}/>) if keyboard_height <= 0 else None}
    </View>;
}
