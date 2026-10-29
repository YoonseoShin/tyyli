"""Browser location adapter.

The browser preview intentionally uses the weather service's city fallback.
The native override requests device permission on iOS and Android.
"""


async def:pub get_device_coordinates -> dict[str, any] | None {
    return None;
}
