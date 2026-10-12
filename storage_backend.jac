"""Browser persistence adapter used by the web test build."""
import from "@react-native-async-storage/async-storage" { default as AsyncStorage }


glob BACKEND_KEY: str = "@tyyli/local-user-data/v4",
    backend_handle: any = None;


def decode_json(value: str, fallback: any) -> any {
    try { return JSON.parse(value); }
    except Exception { return fallback; }
}


async def initialize_backend -> any {
    if backend_handle is None {
        backend_handle = AsyncStorage;
    }
    return backend_handle;
}


async def:pub load_payload -> dict[str, any] {
    backend = await initialize_backend();
    raw: str | None = await backend.getItem(BACKEND_KEY);
    if raw is None or raw == "" {
        return {"profile": None, "clothes": [], "latest_outfit": None};
    }
    payload = decode_json(raw, {"profile": None, "clothes": [], "latest_outfit": None}) as dict[str, any];
    clothes = payload["clothes"] as list;
    for raw_item in clothes {
        item = raw_item as dict[str, any];
        if item.get("occasions") is None {
            item["occasions"] = [];
        }
        if item.get("description") is None {
            item["description"] = "";
        }
    }
    return payload;
}


async def:pub save_profile_payload(profile: dict[str, any]) {
    backend = await initialize_backend();
    payload = await load_payload();
    payload["profile"] = profile;
    await backend.setItem(BACKEND_KEY, JSON.stringify(payload));
}


async def:pub save_clothing_payload(item: dict[str, any]) {
    backend = await initialize_backend();
    payload = await load_payload();
    clothes = payload["clothes"] as list;
    payload["clothes"] = [saved for saved in clothes if saved["clothing_item_id"] != item["clothing_item_id"]] + [item];
    await backend.setItem(BACKEND_KEY, JSON.stringify(payload));
}


async def:pub delete_clothing_payload(clothing_item_id: str) {
    backend = await initialize_backend();
    payload = await load_payload();
    clothes = payload["clothes"] as list;
    payload["clothes"] = [item for item in clothes if item["clothing_item_id"] != clothing_item_id];
    await backend.setItem(BACKEND_KEY, JSON.stringify(payload));
}


async def:pub save_outfit_payload(outfit: dict[str, any]) {
    backend = await initialize_backend();
    payload = await load_payload();
    payload["latest_outfit"] = outfit;
    await backend.setItem(BACKEND_KEY, JSON.stringify(payload));
}


async def:pub clear_payload {
    backend = await initialize_backend();
    await backend.removeItem(BACKEND_KEY);
}
