"""Loads the app's typefaces on iOS and Android (DESIGN_SYSTEM.md 3.1).

The fonts ship inside the app bundle (@expo-google-fonts packages), so loading
is local and fast. Each weight is registered under its own name because Android
ignores `fontWeight` on custom fonts; `ui/kit.jac` refers to these names.
"""
import from "expo-font" { useFonts }
import from "@expo-google-fonts/dm-sans" {
    DMSans_400Regular,
    DMSans_500Medium,
    DMSans_600SemiBold,
    DMSans_700Bold
}
import from "@expo-google-fonts/instrument-serif" {
    InstrumentSerif_400Regular,
    InstrumentSerif_400Regular_Italic
}


# A hook: call it from a component body. True once the fonts are ready, or once
# loading failed (text then falls back to the platform fonts).
def:pub use_app_fonts -> bool {
    result = useFonts({
        "DMSans_400Regular": DMSans_400Regular,
        "DMSans_500Medium": DMSans_500Medium,
        "DMSans_600SemiBold": DMSans_600SemiBold,
        "DMSans_700Bold": DMSans_700Bold,
        "InstrumentSerif_400Regular": InstrumentSerif_400Regular,
        "InstrumentSerif_400Regular_Italic": InstrumentSerif_400Regular_Italic
    });
    return bool(result[0]) or bool(result[1]);
}
