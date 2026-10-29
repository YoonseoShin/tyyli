"""This week's plans and how formal each one is."""
import from "@jac/mobui" { Pressable, ScrollView, Text, View }
import from ..components.AppIcon { AppIcon }
import from ..components.EventRow { EventRow }
import from ..models { CalendarEvent }
import from ..services.calendar_service { events_on }
import from ..services.dates { date_key, day_label }
import from ..ui.kit { C, ui }


def:pub CalendarScreen(events: list[CalendarEvent], on_back: Callable[[], None]) -> JsxElement {
    return <ScrollView style={ui.screen} contentContainerStyle={ui.page}>
        <Pressable onPress={lambda { on_back(); }}>
            <AppIcon name="chevron-left" size={22} color={C.ink}/>
        </Pressable>
        <Text style={ui.title}>Calendar</Text>

        <View style={ui.card}>
            <Text style={ui.label}>GOOGLE CALENDAR</Text>
            <Text style={ui.muted}>Not connected. Showing sample events. Your plans and how formal they are will shape each day's outfit.</Text>
            <Pressable style={[ui.button, ui.buttonGhost]}>
                <Text style={[ui.buttonText, ui.buttonGhostText]}>Connect Google Calendar (coming soon)</Text>
            </Pressable>
        </View>

        {[
            <View key={date_key(offset)} style={ui.card}>
                <Text style={ui.label}>{day_label(offset).upper()}</Text>
                {(<Text style={ui.muted}>No plans</Text>) if not events_on(events, date_key(offset)) else <View style={{"gap": 10}}>{[
                    <EventRow key={e.event_id} event={e}/> for e in events_on(events, date_key(offset))
                ]}</View>}
            </View>
            for offset in range(7)
        ]}
    </ScrollView>;
}
