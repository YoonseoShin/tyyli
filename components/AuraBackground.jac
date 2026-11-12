"""The soft aura behind a redesigned screen (DESIGN_SYSTEM.md 5): a tiny
pre-blurred image of cream with blush and sand light, stretched to fill.
Place it first inside a screen's root view; it ignores touches and is hidden
from screen readers.
"""
import from "@jac/mobui" { Image, Platform, View }
import from ..ui.kit { ui }
import from ..ui.materials { AURA_BG }


def:pub AuraBackground -> JsxElement {
    # On iOS/Android the aura also runs into the status-bar and home-indicator
    # strips and under the floating tab bar (see `ui.auraBleed`).
    return <View style={ui.fill if Platform.OS == "web" else ui.auraBleed} pointerEvents="none" accessibilityElementsHidden={True} importantForAccessibility="no-hide-descendants">
        <Image source={{"uri": AURA_BG}} style={{"width": "100%", "height": "100%"}} resizeMode="stretch"/>
    </View>;
}
