"""Home: today's weather, today's schedule, AI outfit picks, and a shortcut to the stylist."""
import from "@jac/mobui" { Pressable, ScrollView, Text, TextInput, View }
import from ..components.AppIcon { AppIcon }
import from ..components.Button { Button }
import from ..components.OutfitCard { items_for }
import from ..components.OutfitCollage { OutfitCollage }
import from ..models { CalendarEvent, Outfit, WeatherInfo }
import from ..services.calendar_service { formality_label }
import from ..services.dates { date_key }
import from ..services.weather_service { to_unit }
import from ..storage { ClothingItem }
import from ..services.outfit_service { capitalize }
import from ..ui.kit { C, ui }


glob WEEKDAY_NAMES: list[str] = ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"],
    MONTH_NAMES: list[str] = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"],
    DOT_COLORS: list[str] = ["#22170F", "#8B6B55", "#C9B8A6", "#6F7F62"];


def:pub today_label -> str {
    now = new(Date);
    return str(WEEKDAY_NAMES[int(now.getDay())]) + ", " + str(MONTH_NAMES[int(now.getMonth())]) + " " + str(now.getDate());
}

# "10:00" -> "10:00 AM", "18:30" -> "6:30 PM", "09:00 - 10:30" -> "9:00 AM - 10:30 AM".
def _clock_single(time: str) -> str {
    if not time or ":" not in time { return time; }
    parts = time.split(":");
    if len(parts) != 2 { return time; }
    try {
        hour = int(parts[0]);
    } except Exception {
        return time;
    }
    suffix = "PM" if hour >= 12 else "AM";
    shown = hour - 12 if hour > 12 else (12 if hour == 0 else hour);
    return str(shown) + ":" + parts[1] + " " + suffix;
}


def:pub clock_label(time: str) -> str {
    compact = time.strip();
    if "-" in compact {
        parts = [p.strip() for p in compact.split("-") if p.strip()];
        if len(parts) == 2 {
            return _clock_single(parts[0]) + " - " + _clock_single(parts[1]);
        }
    }
    return _clock_single(compact);
}


def WeatherGlyph -> JsxElement {
    return <View style={{"width": 46, "height": 34, "alignItems": "center", "justifyContent": "center"}}>
        <AppIcon name="weather-partly-cloudy" size={33} color={C.accent}/>
    </View>;
}


def PickCard(outfit: Outfit, clothes: list[ClothingItem], top: bool, weather_label: str, on_press: Callable[[], None]) -> JsxElement {
    items = items_for(outfit, clothes);
    ink = C.ink;
    sub = C.muted;
    pick_label = "TOP PICK" if top else (outfit.match_reasons[1].upper() if len(outfit.match_reasons) > 1 else "PICK");
    return <Pressable onPress={lambda { on_press(); }} style={[ui.card, {"width": 168, "padding": 12, "gap": 8, "borderWidth": 2 if top else 1, "borderColor": C.accent if top else C.line}]}>
        <View style={[ui.chip, {"alignSelf": "flex-start", "backgroundColor": C.soft if top else C.surface, "borderWidth": 1, "borderColor": C.accent if top else C.line, "paddingVertical": 4}]}>
            <Text style={{"fontSize": 10, "fontWeight": "bold", "letterSpacing": 0.8, "color": C.accent if top else C.muted}}>{pick_label}</Text>
        </View>
        <OutfitCollage items={items} compact={True} height={130} item_cards={False}/>
        <Text style={{"fontSize": 15, "fontWeight": "bold", "color": ink}} numberOfLines={1}>{outfit.style_name}</Text>
        <Text style={{"fontSize": 12, "lineHeight": 16, "color": sub}} numberOfLines={2}>{" · ".join([i.name for i in items[:3]])}</Text>
        <View style={ui.wrap}>
            {(<View style={[ui.chip, {"paddingVertical": 3, "paddingHorizontal": 8, "backgroundColor": C.soft}]}>
                <Text style={{"fontSize": 11, "color": ink}}>{weather_label}</Text>
            </View>) if weather_label else None}
            {(<View style={[ui.chip, {"paddingVertical": 3, "paddingHorizontal": 8, "backgroundColor": C.soft}]}>
                <Text style={{"fontSize": 11, "color": ink}} numberOfLines={1}>{outfit.event_title}</Text>
            </View>) if outfit.event_title else None}
        </View>
    </Pressable>;
}


def:pub HomeScreen(
    weather: WeatherInfo | None,
    today_events: list[CalendarEvent],
    picks: list[Outfit],
    clothes: list[ClothingItem],
    can_generate: bool,
    generating: bool,
    on_navigate: Callable[[str], None],
    on_open_pick: Callable[[int], None],
    on_generate: Callable[[], None],
    on_events_change: Callable[[list[CalendarEvent]], None],
    on_add_event: Callable[[str, str, str, str, int, str, bool], None] | None = None,
    temperature_unit: str = "F",
    on_toggle_unit: Callable[[], None] | None = None
) -> JsxElement {
    has editing_schedule: bool = False,
        plan_title: str = "",
        plan_time: str = "",
        plan_formality: int = 2,
        plan_major: bool = True;

    def add_plan {
        title = plan_title.strip();
        if not title { return; }
        if on_add_event {
            on_add_event(title, date_key(0), plan_time.strip(), "other", plan_formality, "one_time", plan_major);
            plan_title = "";
            plan_time = "";
            return;
        }
        on_events_change(today_events + [CalendarEvent(
            event_id="test-" + str(Date.now()),
            title=title,
            date=date_key(0),
            start_time=plan_time.strip(),
            kind="other",
            formality=plan_formality,
            is_major=plan_major
        )]);
        plan_title = "";
        plan_time = "";
    }

    def remove_plan(event_id: str) {
        on_events_change([event for event in today_events if event.event_id != event_id]);
    }

    unit = "C" if temperature_unit == "C" else "F";
    temp_label = (str(to_unit(weather.temperature_f, unit)) + "°" + unit) if weather is not None else "";
    times = sorted([e.start_time for e in today_events if e.start_time]);
    return <ScrollView style={ui.screen} contentContainerStyle={ui.page}>
        <View>
            <View>
                <Text style={ui.logo}>tyyli</Text>
                <Text style={ui.label}>{today_label()}</Text>
            </View>
        </View>

        <View style={[ui.card, {"padding": 12, "gap": 6}]}>
            <View style={ui.rowBetween}>
                <View style={[ui.row, {"alignItems": "flex-end"}]}>
                    <Text style={[ui.serifNumber, {"fontSize": 34}]}>{str(to_unit(weather.temperature_f, unit)) + "°" if weather is not None else "--"}</Text>
                    <Pressable onPress={lambda { if on_toggle_unit { on_toggle_unit(); } }} style={{"paddingBottom": 5}}>
                        <Text style={ui.muted}>{unit + (" · " + weather.city if weather is not None and weather.city else "")}</Text>
                    </Pressable>
                </View>
                <WeatherGlyph/>
            </View>
            <Text style={ui.muted}>{(weather.condition + " · H " + str(to_unit(weather.high_f, unit)) + "° / L " + str(to_unit(weather.low_f, unit)) + "°") if weather is not None else "Loading weather..."}</Text>
            <View style={ui.wrap}>
                <View style={ui.chip}><Text style={ui.chipText}>{str(len(today_events)) + (" event today" if len(today_events) == 1 else " events today")}</Text></View>
                {(<View style={ui.chip}><Text style={ui.chipText}>{clock_label(times[0]) + " – " + clock_label(times[len(times) - 1])}</Text></View>) if len(times) > 1 else None}
            </View>
        </View>

        <View style={{"gap": 8}}>
            <View style={ui.rowBetween}>
                <Text style={ui.label}>TODAY'S SCHEDULE</Text>
                <Pressable onPress={lambda { editing_schedule = not editing_schedule; }}>
                    <Text style={ui.link}>{"Done" if editing_schedule else "Edit"}</Text>
                </Pressable>
            </View>
            <View style={[ui.card, {"paddingVertical": 4, "gap": 0}]}>
                {(<Text style={[ui.muted, {"paddingVertical": 14}]}>Nothing scheduled today.</Text>) if not today_events else None}
                {[
                    <View key={e.event_id} style={[ui.rowBetween, {"paddingVertical": 12, "borderTopWidth": 0 if n == 0 else 1, "borderColor": C.line}]}>
                        <View style={[ui.row, ui.flex1, {"gap": 12}]}>
                            <View style={{"width": 7, "height": 7, "borderRadius": 999, "backgroundColor": DOT_COLORS[n % len(DOT_COLORS)]}}/>
                            <View style={ui.flex1}>
                                <Text style={ui.bodyBold} numberOfLines={1}>{e.title}</Text>
                                <Text style={ui.small}>{formality_label(e.formality).lower() + (" · major" if e.is_major else "")}</Text>
                            </View>
                        </View>
                        <Text style={ui.small}>{clock_label(e.start_time)}</Text>
                        {(<Pressable style={{"padding": 4}} onPress={lambda { remove_plan(e.event_id); }}>
                            <AppIcon name="close-circle-outline" size={20} color={C.danger}/>
                        </Pressable>) if editing_schedule else None}
                    </View>
                    for (n, e) in enumerate(today_events)
                ]}
            </View>
            {(
                <View style={[ui.card, {"gap": 12}]}>
                    <Text style={ui.heading}>Add a test plan</Text>
                    <TextInput
                        style={ui.input}
                        value={plan_title}
                        placeholder="Plan name, e.g. Job interview"
                        placeholderTextColor={C.muted}
                        onChangeText={lambda (value: str) { plan_title = value; }}
                    />
                    <TextInput
                        style={ui.input}
                        value={plan_time}
                        placeholder="Time, e.g. 14:30"
                        placeholderTextColor={C.muted}
                        keyboardType="numbers-and-punctuation"
                        onChangeText={lambda (value: str) { plan_time = value; }}
                    />
                    <View style={{"gap": 7}}>
                        <Text style={ui.label}>FORMALITY</Text>
                        <View style={ui.wrap}>
                            {[
                                <Pressable key={str(level)} style={[ui.chip, ui.chipOn if plan_formality == level else None]} onPress={lambda { plan_formality = level; }}>
                                    <Text style={[ui.chipText, ui.chipTextOn if plan_formality == level else None]}>{str(level)}</Text>
                                </Pressable>
                                for level in range(1, 6)
                            ]}
                        </View>
                        <Text style={ui.small}>{formality_label(plan_formality)}</Text>
                    </View>
                    <View style={{"gap": 7}}>
                        <Text style={ui.label}>OUTFIT RECOMMENDATION</Text>
                        <View style={ui.wrap}>
                            <Pressable style={[ui.chip, ui.chipOn if plan_major else None]} onPress={lambda { plan_major = True; }}>
                                <Text style={[ui.chipText, ui.chipTextOn if plan_major else None]}>Major event</Text>
                            </Pressable>
                            <Pressable style={[ui.chip, ui.chipOn if not plan_major else None]} onPress={lambda { plan_major = False; }}>
                                <Text style={[ui.chipText, ui.chipTextOn if not plan_major else None]}>Regular plan</Text>
                            </Pressable>
                        </View>
                        <Text style={ui.small}>Major events receive their own outfit in addition to the all-day look.</Text>
                    </View>
                    <Button label="Add plan" disabled={not plan_title.strip()} on_press={lambda { add_plan(); }}/>
                    <Button label="Open calendar planner" kind="ghost" on_press={lambda { on_navigate("calendar"); }}/>
                    <Text style={ui.small}>Regenerate Outfit Picks when you want the AI to use your updated schedule.</Text>
                </View>
            ) if editing_schedule else None}
        </View>

        <View style={{"gap": 8}}>
            <View style={ui.rowBetween}>
                <Text style={ui.label}>AI OUTFIT PICKS</Text>
                {(<Pressable onPress={lambda { on_open_pick(0); }}>
                    <Text style={ui.link}>See all</Text>
                </Pressable>) if picks else None}
            </View>
            {(
                <View style={[ui.card, {"gap": 10}]}>
                    <Text style={ui.body}>{"Your closet is ready. Generate today's outfits using your style, weather and plans." if can_generate else "Add and analyze at least a top and a bottom to generate your first outfit picks."}</Text>
                    {(
                        <Button label="Generate outfits" busy={generating} disabled={generating} on_press={lambda { on_generate(); }}/>
                    ) if can_generate else (
                        <Pressable style={ui.button} onPress={lambda { on_navigate("closet"); }}>
                            <Text style={ui.buttonText}>Go to closet</Text>
                        </Pressable>
                    )}
                </View>
            ) if not picks else (
                <ScrollView horizontal={True} showsHorizontalScrollIndicator={False}>
                    <View style={[ui.row, {"gap": 10, "alignItems": "stretch"}]}>
                        {[
                            <PickCard key={p.outfit_id} outfit={p} clothes={clothes} top={n == 0} weather_label={temp_label} on_press={lambda { on_open_pick(n); }}/>
                            for (n, p) in enumerate(picks)
                        ]}
                    </View>
                </ScrollView>
            )}
        </View>

        <Pressable style={[ui.card, ui.rowBetween]} onPress={lambda { on_navigate("chat"); }}>
            <View style={[ui.row, ui.flex1, {"gap": 12}]}>
                <View style={{"width": 34, "height": 34, "borderRadius": 999, "backgroundColor": C.dark, "alignItems": "center", "justifyContent": "center"}}>
                    <AppIcon name="creation-outline" size={18} color={C.accent_text}/>
                </View>
                <View style={ui.flex1}>
                    <Text style={ui.bodyBold}>Ask your stylist</Text>
                    <Text style={ui.small} numberOfLines={1}>What should I wear to a job interview?</Text>
                </View>
            </View>
            <AppIcon name="chevron-right" size={21} color={C.muted}/>
        </Pressable>
    </ScrollView>;
}
