"""Small date helpers so screens and services agree on date strings."""


glob DAY_MS: int = 86400000,
    WEEKDAYS: list[str] = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];


def:pub date_key(days_from_today: int = 0) -> str {
    # YYYY-MM-DD in the device's local time zone.
    day = new(Date, Date.now() + days_from_today * DAY_MS);
    month = str(day.getMonth() + 1);
    date = str(day.getDate());
    return str(day.getFullYear()) + "-" + ("0" + month if len(month) == 1 else month) + "-" + ("0" + date if len(date) == 1 else date);
}


def:pub day_label(days_from_today: int = 0) -> str {
    if days_from_today == 0 { return "Today"; }
    if days_from_today == 1 { return "Tomorrow"; }
    day = new(Date, Date.now() + days_from_today * DAY_MS);
    return str(WEEKDAYS[day.getDay()]) + " " + str(day.getMonth() + 1) + "/" + str(day.getDate());
}
