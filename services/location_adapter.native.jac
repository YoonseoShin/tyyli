"""Native location adapter for iOS and Android."""
import from "expo-location" {
    Accuracy,
    getCurrentPositionAsync,
    requestForegroundPermissionsAsync
}


async def:pub get_device_coordinates -> dict[str, any] | None {
    permission = await requestForegroundPermissionsAsync();
    print("Weather debug: permission status = " + str(permission.status));
    if permission.status != "granted" { return None; }
    location = await getCurrentPositionAsync({"accuracy": Accuracy.Balanced});
    return {
        "lat": float(location.coords.latitude),
        "lon": float(location.coords.longitude)
    };
}
