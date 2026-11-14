"""A calendar event with its formality level and optional remove action."""
import from "@jac/mobui" { Pressable, Text, View }
import from .AppIcon { AppIcon }
import from ..models { CalendarEvent }
import from ..services.calendar_service { formality_label }
import from ..ui.kit { C, ui }


def:pub EventRow(
    event: CalendarEvent,
    on_remove: Callable[[], None] | None = None,
    remove_label: str = "Remove plan"
) -> JsxElement {
    return <View style={ui.rowBetween}>
        <View style={ui.flex1}>
            <Text style={ui.body}>{event.title}</Text>
            <Text style={ui.muted}>{event.start_time if event.start_time else "Any time"}</Text>
        </View>
        <View style={ui.row}>
            <View style={ui.chip}>
                <Text style={ui.chipText}>{formality_label(event.formality)}</Text>
            </View>
            {(<Pressable
                accessibilityRole="button"
                accessibilityLabel={remove_label}
                hitSlop={8}
                style={{"padding": 4}}
                onPress={lambda { if on_remove { on_remove(); } }}
            >
                <AppIcon name="close-circle-outline" size={20} color={C.danger}/>
            </Pressable>) if on_remove else None}
        </View>
    </View>;
}
