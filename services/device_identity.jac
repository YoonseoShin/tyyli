"""Persistent anonymous id used only for per-installation server limits."""
import from "@react-native-async-storage/async-storage" { default as AsyncStorage }


glob DEVICE_ID_KEY: str = "@tyyli/installation-id/v1";


async def:pub get_device_id -> str {
    existing: str | None = await AsyncStorage.getItem(DEVICE_ID_KEY);
    if existing is not None and len(existing) >= 16 {
        return existing;
    }
    generated = (
        "tyyli-" + str(Date.now()) + "-"
        + str(Math.floor(Math.random() * 1000000000)) + "-"
        + str(Math.floor(Math.random() * 1000000000))
    );
    await AsyncStorage.setItem(DEVICE_ID_KEY, generated);
    return generated;
}
