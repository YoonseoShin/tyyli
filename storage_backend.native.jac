"""SQLite persistence adapter for iOS and Android.

When the native bundle runs in a browser (Expo web preview, `expo start` then
open localhost:8081) expo-sqlite never resolves, so everything is kept in
memory for that session instead.
"""
import from "@jac/mobui" { Platform }
import from "expo-sqlite" { openDatabaseAsync }


glob BACKEND_KEY: str = "tyyli-clothes.db",
    backend_handle: any = None;
glob:priv ON_WEB: bool = Platform.OS == "web",
     memory_payload: dict[str, any] = {"profile": None, "clothes": [], "latest_outfit": None};


def decode_json(value: str, fallback: any) -> any {
    try { return JSON.parse(value); }
    except Exception { return fallback; }
}


async def initialize_backend -> any {
    if backend_handle is None {
        backend_handle = await openDatabaseAsync(BACKEND_KEY);
        await backend_handle.execAsync("""
            PRAGMA journal_mode = WAL;
            CREATE TABLE IF NOT EXISTS style_profile (
                id INTEGER PRIMARY KEY CHECK (id = 1),
                preferred_styles TEXT NOT NULL,
                preferred_colors TEXT NOT NULL,
                occasions TEXT NOT NULL,
                inspiration TEXT NOT NULL,
                mbti TEXT NOT NULL,
                zodiac TEXT NOT NULL,
                shop_section TEXT NOT NULL DEFAULT '',
                height TEXT NOT NULL DEFAULT '',
                weight TEXT NOT NULL DEFAULT '',
                top_size TEXT NOT NULL DEFAULT '',
                bottom_size TEXT NOT NULL DEFAULT '',
                shoe_size TEXT NOT NULL DEFAULT '',
                body_shape TEXT NOT NULL DEFAULT '',
                units TEXT NOT NULL DEFAULT '',
                bust TEXT NOT NULL DEFAULT '',
                waist TEXT NOT NULL DEFAULT '',
                hips TEXT NOT NULL DEFAULT '',
                brand_sizes TEXT NOT NULL DEFAULT '[]',
                temperature_unit TEXT NOT NULL DEFAULT '',
                favorite_stores TEXT NOT NULL DEFAULT '[]',
                favorite_brands TEXT NOT NULL DEFAULT '[]',
                style_name TEXT NOT NULL DEFAULT '',
                style_description TEXT NOT NULL DEFAULT '',
                style_palette TEXT NOT NULL DEFAULT '[]',
                style_notes TEXT NOT NULL DEFAULT ''
            );
            CREATE TABLE IF NOT EXISTS clothes (
                id TEXT PRIMARY KEY NOT NULL,
                name TEXT NOT NULL,
                category TEXT NOT NULL,
                colors TEXT NOT NULL,
                seasons TEXT NOT NULL,
                style_tags TEXT NOT NULL,
                occasions TEXT NOT NULL DEFAULT '[]',
                warmth INTEGER NOT NULL DEFAULT 0,
                waterproof INTEGER NOT NULL DEFAULT 0,
                description TEXT NOT NULL DEFAULT '',
                image_path TEXT NOT NULL,
                source_image_url TEXT NOT NULL,
                source_product_url TEXT NOT NULL,
                brand TEXT NOT NULL DEFAULT '',
                price TEXT NOT NULL DEFAULT '',
                original_image_path TEXT NOT NULL DEFAULT '',
                lookup_status TEXT NOT NULL DEFAULT '',
                lookup_note TEXT NOT NULL DEFAULT '',
                created_at TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS latest_outfit (
                id INTEGER PRIMARY KEY CHECK (id = 1),
                clothing_item_ids TEXT NOT NULL,
                reason TEXT NOT NULL,
                created_at TEXT NOT NULL
            );
        """);
        profile_columns = await backend_handle.getAllAsync("PRAGMA table_info(style_profile)");
        profile_column_names = [column["name"] for column in profile_columns];
        for text_column in ["shop_section", "height", "weight", "top_size", "bottom_size", "shoe_size", "body_shape", "units", "bust", "waist", "hips", "temperature_unit", "style_name", "style_description", "style_notes"] {
            if text_column not in profile_column_names {
                await backend_handle.execAsync("ALTER TABLE style_profile ADD COLUMN " + text_column + " TEXT NOT NULL DEFAULT '';");
            }
        }
        for list_column in ["favorite_stores", "favorite_brands", "brand_sizes", "style_palette"] {
            if list_column not in profile_column_names {
                await backend_handle.execAsync("ALTER TABLE style_profile ADD COLUMN " + list_column + " TEXT NOT NULL DEFAULT '[]';");
            }
        }
        clothes_columns = await backend_handle.getAllAsync("PRAGMA table_info(clothes)");
        column_names = [column["name"] for column in clothes_columns];
        if "occasions" not in column_names {
            await backend_handle.execAsync("ALTER TABLE clothes ADD COLUMN occasions TEXT NOT NULL DEFAULT '[]';");
        }
        if "description" not in column_names {
            await backend_handle.execAsync("ALTER TABLE clothes ADD COLUMN description TEXT NOT NULL DEFAULT '';");
        }
        if "brand" not in column_names {
            await backend_handle.execAsync("ALTER TABLE clothes ADD COLUMN brand TEXT NOT NULL DEFAULT '';");
        }
        if "price" not in column_names {
            await backend_handle.execAsync("ALTER TABLE clothes ADD COLUMN price TEXT NOT NULL DEFAULT '';");
        }
        if "original_image_path" not in column_names {
            await backend_handle.execAsync("ALTER TABLE clothes ADD COLUMN original_image_path TEXT NOT NULL DEFAULT '';");
        }
        if "lookup_status" not in column_names {
            await backend_handle.execAsync("ALTER TABLE clothes ADD COLUMN lookup_status TEXT NOT NULL DEFAULT '';");
        }
        if "lookup_note" not in column_names {
            await backend_handle.execAsync("ALTER TABLE clothes ADD COLUMN lookup_note TEXT NOT NULL DEFAULT '';");
        }
    }
    return backend_handle;
}


async def:pub load_payload -> dict[str, any] {
    if ON_WEB { return memory_payload; }
    db = await initialize_backend();
    profile_row = await db.getFirstAsync("SELECT * FROM style_profile WHERE id = 1");
    clothes_rows = await db.getAllAsync("SELECT * FROM clothes ORDER BY created_at DESC");
    outfit_row = await db.getFirstAsync("SELECT * FROM latest_outfit WHERE id = 1");

    profile = None if profile_row is None else {
        "preferred_styles": decode_json(profile_row["preferred_styles"], []),
        "preferred_colors": decode_json(profile_row["preferred_colors"], []),
        "occasions": decode_json(profile_row["occasions"], []),
        "inspiration": profile_row["inspiration"],
        "mbti": profile_row["mbti"],
        "zodiac": profile_row["zodiac"],
        "shop_section": profile_row["shop_section"] or "",
        "height": profile_row["height"] or "",
        "weight": profile_row["weight"] or "",
        "top_size": profile_row["top_size"] or "",
        "bottom_size": profile_row["bottom_size"] or "",
        "shoe_size": profile_row["shoe_size"] or "",
        "body_shape": profile_row["body_shape"] or "",
        "units": profile_row["units"] or "in",
        "bust": profile_row["bust"] or "",
        "waist": profile_row["waist"] or "",
        "hips": profile_row["hips"] or "",
        "brand_sizes": decode_json(profile_row["brand_sizes"] or "[]", []),
        "temperature_unit": profile_row["temperature_unit"] or "F",
        "favorite_stores": decode_json(profile_row["favorite_stores"] or "[]", []),
        "favorite_brands": decode_json(profile_row["favorite_brands"] or "[]", []),
        "style_name": profile_row["style_name"] or "",
        "style_description": profile_row["style_description"] or "",
        "style_palette": decode_json(profile_row["style_palette"] or "[]", []),
        "style_notes": profile_row["style_notes"] or ""
    };
    clothes = [{
        "clothing_item_id": row["id"],
        "name": row["name"],
        "category": row["category"],
        "colors": decode_json(row["colors"], []),
        "seasons": decode_json(row["seasons"], []),
        "style_tags": decode_json(row["style_tags"], []),
        "occasions": decode_json(row["occasions"], []),
        "warmth": row["warmth"],
        "waterproof": row["waterproof"] == 1,
        "description": row["description"],
        "image_path": row["image_path"],
        "source_image_url": row["source_image_url"],
        "source_product_url": row["source_product_url"],
        "brand": row["brand"],
        "price": row["price"],
        "original_image_path": row["original_image_path"],
        "lookup_status": row["lookup_status"],
        "lookup_note": row["lookup_note"],
        "created_at": row["created_at"]
    } for row in clothes_rows];
    latest_outfit = None if outfit_row is None else {
        "clothing_item_ids": decode_json(outfit_row["clothing_item_ids"], []),
        "reason": outfit_row["reason"],
        "created_at": outfit_row["created_at"]
    };
    return {"profile": profile, "clothes": clothes, "latest_outfit": latest_outfit};
}


async def:pub save_profile_payload(profile: dict[str, any]) {
    if ON_WEB { memory_payload = {**memory_payload, "profile": profile}; return; }
    db = await initialize_backend();
    await db.runAsync("""
        INSERT INTO style_profile (
            id, preferred_styles, preferred_colors, occasions, inspiration, mbti, zodiac,
            shop_section, height, weight, top_size, bottom_size, shoe_size, body_shape,
            units, bust, waist, hips, brand_sizes, temperature_unit,
            favorite_stores, favorite_brands,
            style_name, style_description, style_palette, style_notes
        ) VALUES (
            1, $preferred_styles, $preferred_colors, $occasions, $inspiration, $mbti, $zodiac,
            $shop_section, $height, $weight, $top_size, $bottom_size, $shoe_size, $body_shape,
            $units, $bust, $waist, $hips, $brand_sizes, $temperature_unit,
            $favorite_stores, $favorite_brands,
            $style_name, $style_description, $style_palette, $style_notes
        )
        ON CONFLICT(id) DO UPDATE SET
            preferred_styles = excluded.preferred_styles,
            preferred_colors = excluded.preferred_colors,
            occasions = excluded.occasions,
            inspiration = excluded.inspiration,
            mbti = excluded.mbti,
            zodiac = excluded.zodiac,
            shop_section = excluded.shop_section,
            height = excluded.height,
            weight = excluded.weight,
            top_size = excluded.top_size,
            bottom_size = excluded.bottom_size,
            shoe_size = excluded.shoe_size,
            body_shape = excluded.body_shape,
            units = excluded.units,
            bust = excluded.bust,
            waist = excluded.waist,
            hips = excluded.hips,
            brand_sizes = excluded.brand_sizes,
            temperature_unit = excluded.temperature_unit,
            favorite_stores = excluded.favorite_stores,
            favorite_brands = excluded.favorite_brands,
            style_name = excluded.style_name,
            style_description = excluded.style_description,
            style_palette = excluded.style_palette,
            style_notes = excluded.style_notes
    """, {
        "$preferred_styles": JSON.stringify(profile["preferred_styles"]),
        "$preferred_colors": JSON.stringify(profile["preferred_colors"]),
        "$occasions": JSON.stringify(profile["occasions"]),
        "$inspiration": profile["inspiration"],
        "$mbti": profile["mbti"],
        "$zodiac": profile["zodiac"],
        "$shop_section": profile.get("shop_section", "") or "",
        "$height": profile.get("height", "") or "",
        "$weight": profile.get("weight", "") or "",
        "$top_size": profile.get("top_size", "") or "",
        "$bottom_size": profile.get("bottom_size", "") or "",
        "$shoe_size": profile.get("shoe_size", "") or "",
        "$body_shape": profile.get("body_shape", "") or "",
        "$units": profile.get("units", "") or "in",
        "$bust": profile.get("bust", "") or "",
        "$waist": profile.get("waist", "") or "",
        "$hips": profile.get("hips", "") or "",
        "$brand_sizes": JSON.stringify(profile.get("brand_sizes", []) or []),
        "$temperature_unit": profile.get("temperature_unit", "") or "F",
        "$favorite_stores": JSON.stringify(profile.get("favorite_stores", []) or []),
        "$favorite_brands": JSON.stringify(profile.get("favorite_brands", []) or []),
        "$style_name": profile.get("style_name", "") or "",
        "$style_description": profile.get("style_description", "") or "",
        "$style_palette": JSON.stringify(profile.get("style_palette", []) or []),
        "$style_notes": profile.get("style_notes", "") or ""
    });
}


async def:pub save_clothing_payload(item: dict[str, any]) {
    if ON_WEB {
        others = [c for c in memory_payload["clothes"] if c["clothing_item_id"] != item["clothing_item_id"]];
        memory_payload = {**memory_payload, "clothes": others + [item]};
        return;
    }
    db = await initialize_backend();
    await db.runAsync("""
        INSERT INTO clothes (
            id, name, category, colors, seasons, style_tags, occasions, warmth, waterproof,
            description, image_path, source_image_url, source_product_url,
            brand, price, original_image_path, lookup_status, lookup_note, created_at
        ) VALUES (
            $id, $name, $category, $colors, $seasons, $style_tags, $occasions, $warmth, $waterproof,
            $description, $image_path, $source_image_url, $source_product_url,
            $brand, $price, $original_image_path, $lookup_status, $lookup_note, $created_at
        )
        ON CONFLICT(id) DO UPDATE SET
            name = excluded.name,
            category = excluded.category,
            colors = excluded.colors,
            seasons = excluded.seasons,
            style_tags = excluded.style_tags,
            occasions = excluded.occasions,
            warmth = excluded.warmth,
            waterproof = excluded.waterproof,
            description = excluded.description,
            image_path = excluded.image_path,
            source_image_url = excluded.source_image_url,
            source_product_url = excluded.source_product_url,
            brand = excluded.brand,
            price = excluded.price,
            original_image_path = excluded.original_image_path,
            lookup_status = excluded.lookup_status,
            lookup_note = excluded.lookup_note,
            created_at = excluded.created_at
    """, {
        "$id": item["clothing_item_id"],
        "$name": item["name"],
        "$category": item["category"],
        "$colors": JSON.stringify(item["colors"]),
        "$seasons": JSON.stringify(item["seasons"]),
        "$style_tags": JSON.stringify(item["style_tags"]),
        "$occasions": JSON.stringify(item["occasions"]),
        "$warmth": item["warmth"],
        "$waterproof": 1 if item["waterproof"] else 0,
        "$description": item["description"] or "",
        "$image_path": item["image_path"],
        "$source_image_url": item["source_image_url"],
        "$source_product_url": item["source_product_url"],
        "$brand": item.get("brand", "") or "",
        "$price": item.get("price", "") or "",
        "$original_image_path": item.get("original_image_path", "") or "",
        "$lookup_status": item.get("lookup_status", "") or "",
        "$lookup_note": item.get("lookup_note", "") or "",
        "$created_at": item["created_at"]
    });
}


async def:pub delete_clothing_payload(clothing_item_id: str) {
    if ON_WEB {
        memory_payload = {**memory_payload, "clothes": [c for c in memory_payload["clothes"] if c["clothing_item_id"] != clothing_item_id]};
        return;
    }
    db = await initialize_backend();
    await db.runAsync("DELETE FROM clothes WHERE id = $id", {"$id": clothing_item_id});
}


async def:pub save_outfit_payload(outfit: dict[str, any]) {
    if ON_WEB { memory_payload = {**memory_payload, "latest_outfit": outfit}; return; }
    db = await initialize_backend();
    await db.runAsync("""
        INSERT INTO latest_outfit (id, clothing_item_ids, reason, created_at)
        VALUES (1, $clothing_item_ids, $reason, $created_at)
        ON CONFLICT(id) DO UPDATE SET
            clothing_item_ids = excluded.clothing_item_ids,
            reason = excluded.reason,
            created_at = excluded.created_at
    """, {
        "$clothing_item_ids": JSON.stringify(outfit["clothing_item_ids"]),
        "$reason": outfit["reason"],
        "$created_at": outfit["created_at"]
    });
}


async def:pub clear_payload {
    if ON_WEB { memory_payload = {"profile": None, "clothes": [], "latest_outfit": None}; return; }
    db = await initialize_backend();
    await db.execAsync("DELETE FROM latest_outfit; DELETE FROM clothes; DELETE FROM style_profile;");
}
