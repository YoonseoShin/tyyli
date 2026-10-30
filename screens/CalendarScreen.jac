"""Calendar planner with month date picking and simplified recurrence."""
import from "@jac/mobui" { Pressable, ScrollView, Text, TextInput, View }
import from ..components.EventRow { EventRow }
import from ..models { CalendarEvent }
import from ..services.calendar_service { events_on, formality_label }
import from ..services.dates { date_key, day_label }
import from ..ui.kit { ui }


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
    start = new(Date, base + "T00:00:00");
    day = new(Date, start.getTime() + offset * 86400000);
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


def _safe_int(value: str, fallback: int) -> int {
    try {
        parsed = int(value.strip());
        return parsed if parsed > 0 else fallback;
    } except Exception {
        return fallback;
    }
}


def:pub CalendarScreen(
    events: list[CalendarEvent],
    on_add_event: Callable[[str, str, str, str, int, str, bool], None],
    on_remove_event: Callable[[str], None],
    on_back: Callable[[], None]
) -> JsxElement {
    has title: str = "",
        start_time: str = "09:00",
        formality: int = 2,
        repeat_mode: str = "one_time",
        custom_every_days: str = "2",
        custom_count: str = "20",
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
    weekday = _weekday_index(selected_date);

    def submit_manual {
        clean_title = title.strip();
        if not clean_title {
            error = "Add a title first.";
            return;
        }

        recurrence = "one_time";
        if repeat_mode == "daily" {
            recurrence = "daily";
        } elif repeat_mode == "weekly_day" {
            recurrence = "custom|interval=1|count=24|weekdays=" + str(weekday);
        } elif repeat_mode == "custom" {
            recurrence = "custom_days|interval_days=" + str(_safe_int(custom_every_days, 2)) + "|count=" + str(_safe_int(custom_count, 20));
        }

        on_add_event(clean_title, selected_date, start_time, "other", formality, recurrence, True);
        title = "";
        error = "";
    }

    return <ScrollView style={ui.screen} contentContainerStyle={ui.page}>
        <Pressable onPress={lambda { on_back(); }}>
            <Text style={ui.link}>← Back</Text>
        </Pressable>
        <Text style={ui.title}>Calendar</Text>

        <View style={ui.card}>
            <Text style={ui.label}>ADD PLANS</Text>
            <Text style={ui.muted}>Pick a date from the month, set repeat behavior, and plan well in advance.</Text>

            <Text style={ui.label}>Manual event</Text>
            <TextInput
                style={ui.input}
                value={title}
                placeholder="Event title"
                onChangeText={lambda (t: str) { title = t; }}
            />
            <TextInput
                style={ui.input}
                value={start_time}
                placeholder="HH:MM or HH:MM - HH:MM"
                onChangeText={lambda (t: str) { start_time = t; }}
            />

            <Text style={ui.label}>Day</Text>
            <Text style={ui.small}>Selected: {selected_date}</Text>
            <View style={[ui.card, {"padding": 10, "gap": 10}]}>
                <View style={ui.rowBetween}>
                    <Pressable style={ui.chip} onPress={lambda { month_offset = month_offset - 1; }}>
                        <Text style={ui.chipText}>Prev</Text>
                    </Pressable>
                    <Text style={ui.bodyBold}>{_month_label(month_offset)}</Text>
                    <Pressable style={ui.chip} onPress={lambda { month_offset = month_offset + 1; }}>
                        <Text style={ui.chipText}>Next</Text>
                    </Pressable>
                </View>
                <View style={[ui.row, {"justifyContent": "space-between", "gap": 6}]}>
                    {[
                        <View key={str(i)} style={{"flex": 1, "alignItems": "center", "minHeight": 20, "justifyContent": "center"}}>
                            <Text style={ui.small}>{letter}</Text>
                        </View>
                        for (i, letter) in enumerate(["S", "M", "T", "W", "T", "F", "S"])
                    ]}
                </View>
                <View style={{"gap": 6}}>
                    {[
                        <View key={"week-" + str(week_start)} style={[ui.row, {"gap": 6}]}> 
                            {[
                                <Pressable
                                    key={"cell-" + str(week_start) + "-" + str(i)}
                                    disabled={day == ""}
                                    style={{
                                        "flex": 1,
                                        "minHeight": 34,
                                        "borderRadius": 999,
                                        "alignItems": "center",
                                        "justifyContent": "center",
                                        "backgroundColor": "#FFFEFC" if day != "" and selected_date == day else ("#EEE7DE" if day != "" else "transparent")
                                    }}
                                    onPress={lambda { if day != "" { selected_date = day; } }}
                                >
                                    <Text style={ui.chipText}>{_day_num(day) if day != "" else ""}</Text>
                                </Pressable>
                                for (i, day) in enumerate(month_cells[week_start:week_start + 7])
                            ]}
                        </View>
                        for week_start in week_starts
                    ]}
                </View>
            </View>

            <Text style={ui.label}>Repeat</Text>
            <View style={ui.wrap}>
                <Pressable style={[ui.chip, {"backgroundColor": "#FFFEFC" if repeat_mode == "one_time" else "#EEE7DE"}]} onPress={lambda { repeat_mode = "one_time"; }}>
                    <Text style={ui.chipText}>One time</Text>
                </Pressable>
                <Pressable style={[ui.chip, {"backgroundColor": "#FFFEFC" if repeat_mode == "daily" else "#EEE7DE"}]} onPress={lambda { repeat_mode = "daily"; }}>
                    <Text style={ui.chipText}>Daily</Text>
                </Pressable>
                <Pressable style={[ui.chip, {"backgroundColor": "#FFFEFC" if repeat_mode == "weekly_day" else "#EEE7DE"}]} onPress={lambda { repeat_mode = "weekly_day"; }}>
                    <Text style={ui.chipText}>Every {_weekday_name(weekday)}</Text>
                </Pressable>
                <Pressable style={[ui.chip, {"backgroundColor": "#FFFEFC" if repeat_mode == "custom" else "#EEE7DE"}]} onPress={lambda { repeat_mode = "custom"; }}>
                    <Text style={ui.chipText}>Custom</Text>
                </Pressable>
            </View>
            {(
                <View style={[ui.card, {"padding": 10, "gap": 8}]}>
                    <Text style={ui.small}>Repeat every N days with a set number of occurrences.</Text>
                    <TextInput
                        style={ui.input}
                        value={custom_every_days}
                        placeholder="Every 2 days"
                        keyboardType="number-pad"
                        onChangeText={lambda (t: str) { custom_every_days = t if t else "2"; }}
                    />
                    <TextInput
                        style={ui.input}
                        value={custom_count}
                        placeholder="Occurrences, e.g. 20"
                        keyboardType="number-pad"
                        onChangeText={lambda (t: str) { custom_count = t if t else "20"; }}
                    />
                </View>
            ) if repeat_mode == "custom" else None}

            <Text style={ui.label}>Formality</Text>
            <View style={ui.wrap}>
                {[
                    <Pressable key={str(level)} style={[ui.chip, {"backgroundColor": "#FFFEFC" if formality == level else "#EEE7DE"}]} onPress={lambda { formality = level; }}>
                        <Text style={ui.chipText}>{str(level)}</Text>
                    </Pressable>
                    for level in [1, 2, 3, 4, 5]
                ]}
            </View>
            <Text style={ui.small}>{formality_label(formality)}</Text>

            {(<Text style={[ui.muted, {"color": "#9B4A43"}]}>{error}</Text>) if error else None}

            <Pressable style={ui.button} onPress={lambda { submit_manual(); }}>
                <Text style={ui.buttonText}>Add event</Text>
            </Pressable>
        </View>

        {[
            <View key={date_key(offset)} style={ui.card}>
                <Text style={ui.label}>{day_label(offset).upper()}</Text>
                {(<Text style={ui.muted}>No plans</Text>) if not events_on(events, date_key(offset)) else <View style={{"gap": 10}}>{[
                    <View key={e.event_id} style={{"gap": 8}}>
                        <EventRow event={e}/>
                        <Pressable onPress={lambda { on_remove_event(e.event_id); }}>
                            <Text style={ui.link}>Remove</Text>
                        </Pressable>
                    </View>
                    for e in events_on(events, date_key(offset))
                ]}</View>}
            </View>
            for offset in range(7)
        ]}
    </ScrollView>;
}
