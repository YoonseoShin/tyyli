"""SQLite persistence adapter for iOS and Android."""
import from "expo-sqlite" { openDatabaseAsync }


glob BACKEND_KEY: str = "tyyli-clothes.db",
    backend_handle: any = None;


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
                zodiac TEXT NOT NULL
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
                created_at TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS latest_outfit (
                id INTEGER PRIMARY KEY CHECK (id = 1),
                clothing_item_ids TEXT NOT NULL,
                reason TEXT NOT NULL,
                created_at TEXT NOT NULL
            );
        """);
        clothes_columns = await backend_handle.getAllAsync("PRAGMA table_info(clothes)");
        column_names = [column["name"] for column in clothes_columns];
        if "occasions" not in column_names {
            await backend_handle.execAsync("ALTER TABLE clothes ADD COLUMN occasions TEXT NOT NULL DEFAULT '[]';");
        }
        if "description" not in column_names {
            await backend_handle.execAsync("ALTER TABLE clothes ADD COLUMN description TEXT NOT NULL DEFAULT '';");
        }
    }
    return backend_handle;
}


async def:pub load_payload -> dict[str, any] {
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
        "zodiac": profile_row["zodiac"]
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
    db = await initialize_backend();
    await db.runAsync("""
        INSERT INTO style_profile (
            id, preferred_styles, preferred_colors, occasions, inspiration, mbti, zodiac
        ) VALUES (1, $preferred_styles, $preferred_colors, $occasions, $inspiration, $mbti, $zodiac)
        ON CONFLICT(id) DO UPDATE SET
            preferred_styles = excluded.preferred_styles,
            preferred_colors = excluded.preferred_colors,
            occasions = excluded.occasions,
            inspiration = excluded.inspiration,
            mbti = excluded.mbti,
            zodiac = excluded.zodiac
    """, {
        "$preferred_styles": JSON.stringify(profile["preferred_styles"]),
        "$preferred_colors": JSON.stringify(profile["preferred_colors"]),
        "$occasions": JSON.stringify(profile["occasions"]),
        "$inspiration": profile["inspiration"],
        "$mbti": profile["mbti"],
        "$zodiac": profile["zodiac"]
    });
}


async def:pub save_clothing_payload(item: dict[str, any]) {
    db = await initialize_backend();
    await db.runAsync("""
        INSERT INTO clothes (
            id, name, category, colors, seasons, style_tags, occasions, warmth, waterproof,
            description, image_path, source_image_url, source_product_url, created_at
        ) VALUES (
            $id, $name, $category, $colors, $seasons, $style_tags, $occasions, $warmth, $waterproof,
            $description, $image_path, $source_image_url, $source_product_url, $created_at
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
        "$created_at": item["created_at"]
    });
}


async def:pub delete_clothing_payload(clothing_item_id: str) {
    db = await initialize_backend();
    await db.runAsync("DELETE FROM clothes WHERE id = $id", {"$id": clothing_item_id});
}


async def:pub save_outfit_payload(outfit: dict[str, any]) {
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
    db = await initialize_backend();
    await db.execAsync("DELETE FROM latest_outfit; DELETE FROM clothes; DELETE FROM style_profile;");
}
