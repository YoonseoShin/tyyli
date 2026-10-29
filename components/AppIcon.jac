"""One outline icon family shared by navigation, buttons, and status rows."""
import from "@expo/vector-icons" { MaterialCommunityIcons }
import from ..ui.kit { C }


def:pub AppIcon(name: str, size: int = 20, color: str = "") -> JsxElement {
    return <MaterialCommunityIcons name={name} size={size} color={color or C.ink}/>;
}
