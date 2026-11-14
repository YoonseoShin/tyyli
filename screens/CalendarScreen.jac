"""Calendar planner with month date picking and simplified recurrence."""
import from "@jac/mobui" { Pressable, ScrollView, Text, TextInput, View }
import from ..components.AppIcon { AppIcon }
import from ..components.Button { Button }
import from ..components.EventRow { EventRow }
import from ..components.FormalityScale { FormalityScale }
import from ..components.ScreenHeader { ScreenHeader }
import from ..components.Tag { ChoiceChip }
import from ..models { CalendarEvent }
import from ..services.calendar_service { events_on, is_recurring, recurrence_label }
import from ..services.dates { date_key, day_label }
import from ..ui.kit { C, ui }


def _pad2(value: int) -> str {
    text = str(value);
    return "0" + text if len(text) == 1 else text;
}


def _month_start(month_offset: int = 0) -> str {
    month = new(Date);
    month.setDate(1);
    month.setMonth(int(month.getMonth()) + month_offset);
    return str(month.getFullYear()) + "-" + _pad2(int(month.getMonth()) + 1) + "-01";
}


def _date_after(base: str, offset: int) -> str {
    day = new(Date, base + "T00:00:00");
    day.setDate(int(day.getDate()) + offset);
    return str(day.getFullYear()) + "-" + _pad2(int(day.getMonth()) + 1) + "-" + _pad2(int(day.getDate()));
}


def _days_in_month(month_offset: int = 0) -> int {
    month = new(Date);
    month.setDate(1);
    month.setMonth(int(month.getMonth()) + month_offset + 1);
    month.setDate(0);
    return int(month.getDate());
}


def _month_label(month_offset: int = 0) -> str {
    month = new(Date);
    month.setDate(1);
    month.setMonth(int(month.getMonth()) + month_offset);
    names = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
    return names[int(month.getMonth())] + " " + str(month.getFullYear());
}


def _day_num(value: str) -> str {
    parts = value.split("-");
    return str(int(parts[2])) if len(parts) == 3 else value;
}


def _weekday_index(date: str) -> int {
    return int(new(Date, date + "T00:00:00").getDay());
}


def _weekday_name(day: int) -> str {
    labels = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
    return labels[day];
}


def _friendly_date(value: str) -> str {
    date = new(Date, value + "T00:00:00");
    months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
    return _weekday_name(int(date.getDay())) + ", " + months[int(date.getMonth())] + " " + str(date.getDate());
}


def:pub CalendarScreen(
    events: list[CalendarEvent],
    on_add_event: Callable[[str, str, str, str, int, str, bool], None],
    on_remove_occurrence: Callable[[str, str], None],
    on_remove_recurring_rule: Callable[[str], None],
    on_back: Callable[[], None]
) -> JsxElement {
    has title: str = "",
        start_time: str = "09:00",
        formality: int = 2,
        extra_outfit: bool = True,
        repeat_mode: str = "none",
        selected_weekdays: list[int] = [],
        selected_date: str = date_key(0),
        month_offset: int = 0,
        error: str = "";

    month_start = _month_start(month_offset);
    month_dates = [_date_after(month_start, offset) for offset in range(_days_in_month(month_offset))];
    month_start_weekday = _weekday_index(month_start);
    month_cells = ["" for _ in range(month_start_weekday)] + month_dates;
    if len(month_cells) % 7 != 0 {
        month_cells = month_cells + ["" for _ in range(7 - (len(month_cells) % 7))];
    }
    week_starts = [w * 7 for w in range(int(len(month_cells) / 7))];
    weekday_order = [1, 2, 3, 4, 5, 6, 0];
    def toggle_weekday(day: int) {
        updated: list[int] = [];
        if day in selected_weekdays {
            if len(selected_weekdays) == 1 { return; }
            updated = [value for value in selected_weekdays if value != day];
        } else {
            updated = selected_weekdays + [day];
        }
        if len(updated) == 7 {
            repeat_mode = "daily";
            selected_weekdays = weekday_order;
        } else {
            repeat_mode = "custom";
            selected_weekdays = updated;
        }
    }

    def choose_custom_repeat {
        if repeat_mode == "custom" and selected_weekdays { return; }
        repeat_mode = "custom";
        selected_weekdays = [_weekday_index(selected_date)];
    }

    def submit_manual {
        clean_title = title.strip();
        if not clean_title {
            error = "Add a title first.";
            return;
        }
        recurrence = "one_time";
        if repeat_mode == "daily" {
            recurrence = "daily";
        } elif repeat_mode == "custom" and selected_weekdays {
            recurrence = "custom|interval=1|weekdays=" + ",".join([str(day) for day in selected_weekdays]);
        }

        on_add_event(clean_title, selected_date, start_time, "other", formality, recurrence, extra_outfit);
        title = "";
        error = "";
    }

    upcoming_offsets = [offset for offset in range(7)];
    recurring_rules = [event for event in events if is_recurring(event)];

    return <ScrollView style={ui.screen} contentContainerStyle={ui.page} showsVerticalScrollIndicator={False}>
        <ScreenHeader title="Calendar planner" on_back={lambda { on_back(); }}/>

        <View style={[ui.card, {"gap": 14}]}>
            <View style={ui.rowBetween}>
                <Text style={ui.label}>1 · DATE</Text>
                <View style={[ui.chip, ui.chipOn]}>
                    <Text style={ui.chipTextOn}>{_friendly_date(selected_date)}</Text>
                </View>
            </View>

            <View style={[ui.card, {"padding": 10, "gap": 10, "backgroundColor": C.champagne}]}>
                <View style={ui.rowBetween}>
                    <Pressable accessibilityRole="button" accessibilityLabel="Previous month" style={ui.glassCircle} onPress={lambda { month_offset = month_offset - 1; }}>
                        <AppIcon name="chevron-left" size={20} color={C.text_primary}/>
                    </Pressable>
                    <Text style={ui.bodyBold}>{_month_label(month_offset)}</Text>
                    <Pressable accessibilityRole="button" accessibilityLabel="Next month" style={ui.glassCircle} onPress={lambda { month_offset = month_offset + 1; }}>
                        <AppIcon name="chevron-right" size={20} color={C.text_primary}/>
                    </Pressable>
                </View>
                <View style={[ui.row, {"justifyContent": "space-between", "gap": 6}]}>
                    {[
                        <View key={str(i)} style={{"flex": 1, "alignItems": "center", "minHeight": 20, "justifyContent": "center"}}>
                            <Text style={ui.small}>{label}</Text>
                        </View>
                        for (i, label) in enumerate(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"])
                    ]}
                </View>
                <View style={{"gap": 6}}>
                    {[
                        <View key={"week-" + str(week_start)} style={[ui.row, {"gap": 6}]}>
                            {[
                                <Pressable
                                    key={"cell-" + str(week_start) + "-" + str(i)}
                                    accessibilityRole="button"
                                    accessibilityLabel={_friendly_date(day) if day else ""}
                                    disabled={day == ""}
                                    style={[
                                        {"flex": 1, "minHeight": 38, "borderRadius": 999, "alignItems": "center", "justifyContent": "center", "backgroundColor": C.surface if day else "transparent"},
                                        ui.chipOn if day and selected_date == day else None,
                                        {"borderWidth": 1, "borderColor": C.accent} if day and day == date_key(0) and selected_date != day else None
                                    ]}
                                    onPress={lambda { if day { selected_date = day; } }}
                                >
                                    <Text style={[ui.chipText, ui.chipTextOn if day and selected_date == day else None]}>{_day_num(day) if day else ""}</Text>
                                </Pressable>
                                for (i, day) in enumerate(month_cells[week_start:week_start + 7])
                            ]}
                        </View>
                        for week_start in week_starts
                    ]}
                </View>
            </View>
        </View>

        <View style={[ui.card, {"gap": 14}]}>
            <Text style={ui.label}>2 · PLAN DETAILS</Text>
            <View style={{"gap": 7}}>
                <Text style={ui.bodyBold}>Plan name</Text>
                <TextInput
                    style={ui.input}
                    value={title}
                    placeholder="e.g. Dinner with friends"
                    placeholderTextColor={C.muted}
                    onChangeText={lambda (t: str) { title = t; }}
                />
            </View>
            <View style={{"gap": 7}}>
                <Text style={ui.bodyBold}>Start time</Text>
                <TextInput
                    style={ui.input}
                    value={start_time}
                    placeholder="e.g. 18:30"
                    placeholderTextColor={C.muted}
                    keyboardType="numbers-and-punctuation"
                    onChangeText={lambda (t: str) { start_time = t; }}
                />
            </View>
        </View>

        <View style={[ui.card, {"gap": 14}]}>
            <Text style={ui.label}>3 · REPEAT</Text>
            <View style={{"gap": 10, "padding": 12, "borderRadius": 16, "backgroundColor": C.champagne, "borderWidth": 1, "borderColor": C.divider}}>
                <Text style={ui.bodyBold}>Frequency</Text>
                <View style={ui.wrap}>
                    <ChoiceChip label="No repeat" selected={repeat_mode == "none"} on_press={lambda { repeat_mode = "none"; selected_weekdays = []; }}/>
                    <ChoiceChip label="Every day" selected={repeat_mode == "daily"} on_press={lambda { repeat_mode = "daily"; selected_weekdays = weekday_order; }}/>
                    <ChoiceChip label="Custom" selected={repeat_mode == "custom"} on_press={lambda { choose_custom_repeat(); }}/>
                </View>
            </View>
            {(<View style={{"gap": 10, "padding": 12, "borderRadius": 16, "backgroundColor": C.champagne, "borderWidth": 1, "borderColor": C.divider}}>
                <Text style={ui.bodyBold}>Days</Text>
                <View style={ui.wrap}>
                    {[
                        <ChoiceChip key={str(day)} label={_weekday_name(day)[:3]} selected={day in selected_weekdays} on_press={lambda { toggle_weekday(day); }}/>
                        for day in weekday_order
                    ]}
                </View>
            </View>) if repeat_mode == "custom" else None}
        </View>

        <View style={[ui.card, {"gap": 14}]}>
            <Text style={ui.label}>4 · OUTFIT PREFERENCES</Text>
            <View style={{"gap": 10, "padding": 12, "borderRadius": 16, "backgroundColor": C.champagne, "borderWidth": 1, "borderColor": C.divider}}>
                <FormalityScale value={formality} on_change={lambda (level: int) { formality = level; }}/>
            </View>
            <View style={{"gap": 10, "padding": 12, "borderRadius": 16, "backgroundColor": C.champagne, "borderWidth": 1, "borderColor": C.divider}}>
                <Text style={ui.label}>ADDITIONAL OUTFIT</Text>
                <Text style={ui.bodyBold}>Would you like an additional outfit recommendation just for this plan?</Text>
                <View style={ui.wrap}>
                    <ChoiceChip label="Yes" selected={extra_outfit} on_press={lambda { extra_outfit = True; }}/>
                    <ChoiceChip label="No" selected={not extra_outfit} on_press={lambda { extra_outfit = False; }}/>
                </View>
            </View>
        </View>

        {(<Text style={[ui.muted, {"color": C.danger, "textAlign": "center"}]}>{error}</Text>) if error else None}
        <Button label="Save plan" disabled={not title.strip()} on_press={lambda { submit_manual(); }}/>

        <View style={{"gap": 8}}>
            <Text style={ui.label}>RECURRING SCHEDULES</Text>
            {(<View style={ui.card}><Text style={ui.muted}>No recurring schedules</Text></View>) if not recurring_rules else None}
            {[
                <View key={rule.event_id} style={[ui.card, {"padding": 14, "gap": 10, "borderWidth": 1, "borderColor": C.divider}]}>
                    <EventRow
                        event={rule}
                        on_remove={lambda { on_remove_recurring_rule(rule.event_id); }}
                        remove_label="Delete the entire recurring schedule"
                    />
                    <View style={ui.divider}/>
                    <Text style={ui.small}>{recurrence_label(rule)} · Starts {_friendly_date(rule.date)}</Text>
                </View>
                for rule in recurring_rules
            ]}
        </View>

        <View style={{"gap": 8}}>
            <Text style={ui.label}>UPCOMING PLANS</Text>
            {[
                <View key={date_key(offset)} style={[ui.card, {"gap": 12}]}>
                    <Text style={ui.bodyBold}>{day_label(offset)}</Text>
                    <View style={{"gap": 12}}>
                        {(<Text style={ui.muted}>No plans</Text>) if not events_on(events, date_key(offset)) else None}
                        {[
                            <View key={e.event_id} style={{"gap": 8, "padding": 12, "borderRadius": 14, "borderWidth": 1, "borderColor": C.divider, "backgroundColor": C.champagne}}>
                                <EventRow
                                    event={e}
                                    on_remove={lambda { on_remove_occurrence(e.event_id, date_key(offset)); }}
                                    remove_label={"Remove this occurrence" if is_recurring(e) else "Remove plan"}
                                />
                                {(<View style={[ui.chip, {"alignSelf": "flex-start", "paddingHorizontal": 8, "paddingVertical": 3, "backgroundColor": C.soft}]}>
                                    <Text style={{"fontSize": 10, "fontWeight": "600", "color": C.text_secondary}}>Recurring</Text>
                                </View>) if is_recurring(e) else None}
                            </View>
                            for e in events_on(events, date_key(offset))
                        ]}
                    </View>
                </View>
                for offset in upcoming_offsets
            ]}
        </View>
    </ScrollView>;
}
