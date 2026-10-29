"""Turns the onboarding answers into a named style: asks the Claude-backed
server, and falls back to a simple local name and palette when the server or
the API key is missing, so onboarding always ends with a result."""
import from ..storage { StyleProfile }
import from ..style_identity { StyleIdentity, discover_style }


glob COLOR_HEX: dict[str, str] = {
    "Black": "#1F1B18", "White": "#F7F5F1", "Cream": "#F1E6D3", "Brown": "#6B4A32", "Grey": "#9C9A96",
    "Navy": "#1F2A44", "Blue": "#3F6B9E", "Green": "#4A6B4F", "Red": "#8F2D32", "Pink": "#E4A7B3",
    "Yellow": "#E6C46A", "Purple": "#6A4C93"
};
glob NEUTRALS: list[str] = ["#F1E6D3", "#C9B8A8", "#8A7461", "#4A3A2E", "#1F1B18"];


def _join(values: list[str]) -> str {
    return ", ".join(values) if values else "-";
}


def:pub profile_summary(profile: StyleProfile, notes: str = "") -> str {
    lines: list[str] = [];
    if notes.strip() { lines.append("In their own words: " + notes.strip()); }
    lines.append("Styles they identify with: " + _join(profile.preferred_styles));
    lines.append("Colours they like wearing: " + _join(profile.preferred_colors));
    lines.append("Dresses mostly for: " + _join(profile.occasions));
    if profile.shop_section { lines.append("Shops the " + profile.shop_section + " section"); }
    if profile.favorite_stores { lines.append("Favourite stores: " + _join(profile.favorite_stores)); }
    if profile.favorite_brands { lines.append("Favourite brands: " + _join(profile.favorite_brands)); }
    if profile.inspiration { lines.append("Style inspiration: " + profile.inspiration); }
    if profile.body_shape { lines.append("Body shape: " + profile.body_shape); }
    if profile.mbti { lines.append("MBTI: " + profile.mbti); }
    if profile.zodiac { lines.append("Zodiac: " + profile.zodiac); }
    return "\n".join(lines);
}


def:pub local_identity(profile: StyleProfile) -> StyleIdentity {
    picks = profile.preferred_styles;
    name = " ".join(picks[:2]) if picks else "Effortless Everyday";
    where = ("Start at " + ", ".join(profile.favorite_stores[:2]) + ".") if profile.favorite_stores else "Build it from pieces you already reach for.";
    description = (
        "You lean " + (", ".join([p.lower() for p in picks[:3]]) if picks else "easy and wearable")
        + ", with " + (", ".join([c.lower() for c in profile.preferred_colors[:3]]) if profile.preferred_colors else "a flexible")
        + " palette at the core. Your days are mostly " + (", ".join([o.lower() for o in profile.occasions[:3]]) if profile.occasions else "everyday")
        + ", so the stylist will keep outfits comfortable first and polished second. " + where
    );
    palette = [COLOR_HEX[c] for c in profile.preferred_colors if c in COLOR_HEX][:5];
    for n in NEUTRALS {
        if len(palette) >= 5 { break; }
        if n not in palette { palette.append(n); }
    }
    return StyleIdentity(name=name, description=description, palette=palette);
}


async def:pub discover_style_identity(profile: StyleProfile, notes: str = "") -> StyleIdentity {
    try {
        identity: StyleIdentity = await discover_style(profile_summary(profile, notes));
        if identity.name and identity.description {
            if len(identity.palette) < 5 {
                identity.palette = local_identity(profile).palette;
            }
            return identity;
        }
    } except Exception as e {
        print("[style] falling back to a local style name: " + str(e));
    }
    return local_identity(profile);
}
