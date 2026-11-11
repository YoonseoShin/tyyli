"""Tyyli mobile app entry point."""
import from "@jac/mobui" { View }
import from .screens.AppShell { AppShell }
import from .ui.fonts { use_app_fonts }


def:pub app -> JsxElement {
    has font_wait_over: bool = False;

    can with entry {
        # Never hold the app on a blank screen: after 3 s render with whatever
        # fonts are available (the platform fonts stand in).
        _ = setTimeout(lambda { font_wait_over = True; }, 3000);
    }

    fonts_ready = use_app_fonts();
    if not fonts_ready and not font_wait_over {
        return <View style={{"flex": 1, "backgroundColor": "#F7F3EF"}}/>;
    }
    # `jac run --dev` injects the current developer machine's API URL.
    return <AppShell/>;
}
