"""Create Apple App Attest assertions for paid server requests on iPhone."""
import from "@jac/mobui" { Platform }
import from "expo-modules-core" { requireOptionalNativeModule }
import from "expo-secure-store" {
    getItemAsync,
    setItemAsync
}
import from ..app_integrity {
    app_attest_key_registered,
    authorize_app_request,
    create_app_attest_challenge,
    register_app_attest_key
}
import from .device_identity { get_device_id }


glob:priv APP_ATTEST_KEY_STORE: str = "tyyli.app-attest-key-id.v1",
    # Expo Go does not bundle this native module. Loading it optionally keeps
    # the simulator usable while a TestFlight/native build still receives the
    # real ExpoAppIntegrity implementation and performs App Attest normally.
    APP_ATTEST_MODULE: any = requireOptionalNativeModule("ExpoAppIntegrity");


async def _enroll_app_attest_key -> str {
    key_id: str = await APP_ATTEST_MODULE.generateKeyAsync();
    challenge: dict[str, str] = await create_app_attest_challenge(
        "register", key_id, ""
    );
    attestation: str = await APP_ATTEST_MODULE.attestKeyAsync(
        key_id, challenge.get("challenge", "")
    );
    await register_app_attest_key(
        key_id,
        challenge.get("challenge_id", ""),
        attestation
    );
    await setItemAsync(APP_ATTEST_KEY_STORE, key_id);
    return key_id;
}


async def _registered_key -> str {
    stored: str | None = await getItemAsync(APP_ATTEST_KEY_STORE);
    if stored is not None and await app_attest_key_registered(stored) {
        return stored;
    }
    return await _enroll_app_attest_key();
}


async def:pub get_feature_authorization(feature: str) -> str {
    if Platform.OS != "ios" or APP_ATTEST_MODULE is None or not APP_ATTEST_MODULE.isSupported {
        # The server accepts this only while the staged compatibility flag is
        # enabled. Strict production mode accepts real iPhone assertions only.
        return await get_device_id();
    }
    key_id = await _registered_key();
    challenge: dict[str, str] = await create_app_attest_challenge(
        "assertion", key_id, feature
    );
    assertion: str = await APP_ATTEST_MODULE.generateAssertionAsync(
        key_id, challenge.get("challenge", "")
    );
    return await authorize_app_request(
        feature,
        key_id,
        challenge.get("challenge_id", ""),
        assertion
    );
}
