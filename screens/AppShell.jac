"""App shell: loads data, gates on onboarding, and switches between screens.

Navigation is plain state: `tab` is the bottom-tab screen, `route` is a
full-screen page opened on top (calendar, onboarding, storage test).
"""
import from "@jac/mobui" { Pressable, Text, View, useWindowDimensions }
import from ..components.StyleProfileOnboarding { StyleProfileOnboarding }
import from ..components.TabBar { TABS, TabBar }
import from ..models { CalendarEvent, ChatMessage, WeatherInfo }
import from ..services.calendar_service { events_on, get_week_events }
import from ..services.chat_service { send_chat_message }
import from ..services.dates { date_key }
import from ..services.outfit_service { build_outfit, build_week }
import from ..services.weather_service { get_today_weather }
import from ..storage { LocalUserData, StyleProfile, load_local_data, save_profile }
import from ..storage_test { StorageTestScreen }
import from ..ui.kit { ui }
import from .CalendarScreen { CalendarScreen }
import from .ChatScreen { ChatScreen }
import from .ClosetScreen { ClosetScreen }
import from .HomeScreen { HomeScreen }
import from .OutfitsScreen { OutfitsScreen }
import from .ProfileScreen { ProfileScreen }


def:pub AppShell -> JsxElement {
    has data: LocalUserData = LocalUserData(),
        loaded: bool = False,
        load_error: str = "",
        weather: WeatherInfo | None = None,
        events: list[CalendarEvent] = [],
        tab: str = "home",
        route: str = "",
        messages: list[ChatMessage] = [],
        sending: bool = False;
    # Pin the shell to the window height so the tab bar stays at the bottom on web.
    viewport = useWindowDimensions();

    async def reload {
        try {
            data = await load_local_data();
            load_error = "";
        } except Exception as e {
            load_error = "Could not load your data: " + str(e);
        }
        loaded = True;
    }

    async can with entry {
        await reload();
        weather = await get_today_weather();
        events = await get_week_events();
    }

    def navigate(target: str) {
        if target in [t[0] for t in TABS] {
            tab = target;
            route = "";
        } else {
            route = target;
        }
    }

    async def finish_onboarding(profile: StyleProfile) {
        data = await save_profile(profile);
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
        return <StyleProfileOnboarding on_finish={lambda (p: StyleProfile) { finish_onboarding(p); }}/>;
    }

    if route == "calendar" {
        return <View style={[ui.app, {"height": viewport.height}]}>
            <CalendarScreen events={events} on_back={lambda { route = ""; }}/>
        </View>;
    }

    if route == "storage_test" {
        return <View style={[ui.app, {"height": viewport.height}]}>
            <Pressable style={{"padding": 16}} onPress={lambda { route = ""; reload(); }}>
                <Text style={ui.link}>← Back to app</Text>
            </Pressable>
            <StorageTestScreen/>
        </View>;
    }

    today_events = events_on(events, date_key(0));
    today_outfit = build_outfit(data.clothes, data.profile, weather, events, 0);
    week = build_week(data.clothes, data.profile, weather, events);

    return <View style={[ui.app, {"height": viewport.height}]}>
        {(<Text style={[ui.muted, {"padding": 16}]}>{load_error}</Text>) if load_error else None}
        <View style={ui.flex1}>
            {(<HomeScreen weather={weather} today_events={today_events} today_outfit={today_outfit} clothes={data.clothes} on_navigate={lambda (t: str) { navigate(t); }}/>) if tab == "home" else None}
            {(<ClosetScreen clothes={data.clothes} on_changed={lambda { reload(); }}/>) if tab == "closet" else None}
            {(<OutfitsScreen today={today_outfit} week={week} clothes={data.clothes}/>) if tab == "outfits" else None}
            {(<ChatScreen messages={messages} sending={sending} clothes={data.clothes} on_send={lambda (t: str) { send_message(t); }}/>) if tab == "chat" else None}
            {(<ProfileScreen profile={data.profile} clothes_count={len(data.clothes)} on_edit_profile={lambda { route = "onboarding"; }} on_open_storage_test={lambda { route = "storage_test"; }}/>) if tab == "profile" else None}
        </View>
        <TabBar active={tab} on_select={lambda (t: str) { navigate(t); }}/>
    </View>;
}
