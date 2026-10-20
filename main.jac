"""Tyyli mobile app entry point."""
import from .screens.AppShell { AppShell }


def:pub app -> JsxElement {
    # `jac run --dev` injects the current developer machine's API URL.
    return <AppShell/>;
}
