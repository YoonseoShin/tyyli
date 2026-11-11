"""Web counterpart of `ui/fonts.native.jac`: the browser build does not bundle
the font files, so `ui/kit.jac` names the CSS families with system fallbacks and
there is nothing to wait for.
"""


def:pub use_app_fonts -> bool {
    return True;
}
