"""Web/Expo Go fallback while App Attest is unavailable."""
import from .device_identity { get_device_id }


async def:pub get_feature_authorization(feature: str) -> str {
    return await get_device_id();
}
