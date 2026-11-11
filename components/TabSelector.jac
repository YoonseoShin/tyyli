"""Segmented selector on a soft glass track (DESIGN_SYSTEM.md 6).

Switches between named views: outfit looks, swap categories, closet filters.
The selected option sits on a white thumb. With `scroll` the options keep
their natural width and the track scrolls sideways; otherwise they share the
width equally.
"""
import from "@jac/mobui" { Pressable, ScrollView, Text, View }
import from ..ui.kit { ui }


# options: labels (also used as keys, so they must be unique).
# counts:  optional badge number per option, in the same order.
def:pub TabSelector(
    options: list[str],
    selected: str,
    on_select: Callable[[str], None],
    counts: list[int] | None = None,
    scroll: bool = True
) -> JsxElement {
    badges: list[int] = counts if counts is not None else [];
    items = [
        <Pressable
            key={option}
            accessibilityRole="tab"
            accessibilityLabel={option + ((", " + str(badges[n]) + " items") if n < len(badges) else "")}
            accessibilityState={{"selected": option == selected}}
            hitSlop={{"top": 4, "bottom": 4}}
            style={[ui.segItem, ui.segItemOn if option == selected else None, None if scroll else ui.flex1]}
            onPress={lambda { on_select(option); }}
        >
            <Text style={[ui.segText, ui.segTextOn if option == selected else None]} numberOfLines={1}>{option}</Text>
            {(
                <View style={[ui.segCount, ui.segCountOn if option == selected else None]}>
                    <Text style={[ui.segCountText, ui.segCountTextOn if option == selected else None]}>{str(badges[n])}</Text>
                </View>
            ) if n < len(badges) else None}
        </Pressable>
        for (n, option) in enumerate(options)
    ];
    if not scroll {
        return <View style={ui.segTrack} accessibilityRole="tablist">{items}</View>;
    }
    return <ScrollView horizontal={True} showsHorizontalScrollIndicator={False}>
        <View style={ui.segTrack} accessibilityRole="tablist">{items}</View>
    </ScrollView>;
}
