"""A calendar event with its formality level."""
import from "@jac/mobui" { Text, View }
import from ..models { CalendarEvent }
import from ..services.calendar_service { formality_label }
import from ..ui.kit { ui }


def:pub EventRow(event: CalendarEvent) -> JsxElement {
    return <View style={ui.rowBetween}>
        <View style={ui.flex1}>
            <Text style={ui.body}>{event.title}</Text>
            <Text style={ui.muted}>{event.start_time if event.start_time else "Any time"}</Text>
        </View>
        <View style={ui.chip}>
            <Text style={ui.chipText}>{formality_label(event.formality)}</Text>
        </View>
    </View>;
}
