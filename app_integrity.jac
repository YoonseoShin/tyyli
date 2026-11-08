"""Apple App Attest enrollment and one-time authorization for paid AI calls.

The iPhone creates the private key in Secure Enclave. This server verifies the
Apple attestation once, persists only the public key and assertion counter in
Upstash, and verifies a fresh assertion before issuing each one-use AI token.
"""
import asyncio;
import base64;
import hashlib;
import importlib;
import json;
import os;
import secrets;
import time;
import from .rate_limit {
    enforce_device_rate_limit,
    enforce_global_daily_limit,
    upstash_command,
    upstash_configured
}


def _verifier_types -> tuple[any, any, any, any] {
    assertion_module = importlib.import_module("pyattest.assertion");
    attestation_module = importlib.import_module("pyattest.attestation");
    apple_config = importlib.import_module("pyattest.configs.apple");
    serialization = importlib.import_module(
        "cryptography.hazmat.primitives.serialization"
    );
    return (
        assertion_module.Assertion,
        attestation_module.Attestation,
        apple_config.AppleConfig,
        serialization.load_der_public_key
    );
}


glob _ALLOWED_FEATURES: list[str] = [
    "clothing-analysis",
    "outfit-recommendation",
    "outfit-explanation",
    "product-lookup",
    "stylist-chat",
    "style-identity"
];


def _truthy_env(name: str, fallback: bool = False) -> bool {
    value = os.environ.get(name, "true" if fallback else "false").strip().lower();
    return value in ["1", "true", "yes", "on"];
}


def _apple_app_id -> str {
    explicit = os.environ.get("TYYLI_APPLE_APP_ID", "").strip();
    if explicit { return explicit; }
    team_id = os.environ.get("TYYLI_APPLE_TEAM_ID", "48P4DA4TU3").strip();
    bundle_id = os.environ.get(
        "TYYLI_IOS_BUNDLE_ID", "com.yoonseoshin.tyyli"
    ).strip();
    return team_id + "." + bundle_id;
}


def _decode_base64(value: str) -> bytes {
    cleaned = value.strip();
    cleaned += "=" * ((4 - len(cleaned) % 4) % 4);
    return base64.urlsafe_b64decode(cleaned.encode("ascii"));
}


def _key_hash(key_id: str) -> str {
    return hashlib.sha256(key_id.strip().encode("utf-8")).hexdigest();
}


def _key_store_name(key_id: str) -> str {
    return "tyyli:appattest:key:" + _key_hash(key_id);
}


def _challenge_store_name(challenge_id: str) -> str {
    return "tyyli:appattest:challenge:" + challenge_id;
}


def _authorization_store_name(token: str) -> str {
    digest = hashlib.sha256(token.encode("utf-8")).hexdigest();
    return "tyyli:appattest:authorization:" + digest;
}


def _pairs_to_dict(raw: any) -> dict[str, str] {
    if isinstance(raw, dict) {
        return {str(key): str(value) for (key, value) in raw.items()};
    }
    values = raw if isinstance(raw, list) else [];
    return {
        str(values[index]): str(values[index + 1])
        for index in range(0, len(values) - 1, 2)
    };
}


def _consume_challenge(challenge_id: str) -> dict[str, any] {
    raw = upstash_command(["GETDEL", _challenge_store_name(challenge_id)]);
    if raw is None {
        raise RuntimeError("The App Attest challenge is invalid or expired.");
    }
    try { return json.loads(str(raw)) as dict[str, any]; }
    except Exception {
        raise RuntimeError("The App Attest challenge is invalid.");
    }
}


def:pub app_attest_key_registered(key_id: str) -> bool {
    if not key_id.strip() or not upstash_configured() { return False; }
    return bool(upstash_command(["EXISTS", _key_store_name(key_id)]));
}


def:pub create_app_attest_challenge(
    kind: str,
    key_id: str = "",
    feature: str = ""
) -> dict[str, str] {
    if not upstash_configured() {
        raise RuntimeError("App Attest storage is not configured on the server.");
    }
    if kind not in ["register", "assertion"] {
        raise ValueError("Unknown App Attest challenge kind.");
    }
    if not key_id.strip() {
        raise ValueError("An App Attest key identifier is required.");
    }
    if kind == "assertion" {
        if feature not in _ALLOWED_FEATURES {
            raise ValueError("Unknown protected feature.");
        }
        if not app_attest_key_registered(key_id) {
            raise RuntimeError("This App Attest key is not registered.");
        }
    }
    challenge_id = secrets.token_urlsafe(24);
    challenge = secrets.token_urlsafe(32);
    record = json.dumps({
        "kind": kind,
        "key_hash": _key_hash(key_id),
        "feature": feature,
        "challenge": challenge
    });
    stored = upstash_command([
        "SET", _challenge_store_name(challenge_id), record, "EX", "300", "NX"
    ]);
    if str(stored).upper() != "OK" {
        raise RuntimeError("Could not create an App Attest challenge.");
    }
    return {"challenge_id": challenge_id, "challenge": challenge};
}


def:pub register_app_attest_key(
    key_id: str,
    challenge_id: str,
    attestation_data: str
) -> bool {
    record = _consume_challenge(challenge_id);
    if record.get("kind") != "register" or record.get("key_hash") != _key_hash(key_id) {
        raise RuntimeError("The App Attest registration challenge does not match.");
    }
    challenge = str(record.get("challenge", ""));
    (_Assertion, Attestation, AppleConfig, _load_der_public_key) = _verifier_types();
    config = AppleConfig(
        key_id=_decode_base64(key_id),
        app_id=_apple_app_id(),
        production=True
    );
    attestation = Attestation(
        _decode_base64(attestation_data),
        challenge.encode("utf-8"),
        config
    );
    asyncio.run(attestation.verify());
    certificate = attestation.data["certs"].last;
    public_key_der = certificate.public_key.dump();
    store_name = _key_store_name(key_id);
    upstash_command([
        "HSET", store_name,
        "public_key", base64.b64encode(public_key_der).decode("ascii"),
        "counter", "0",
        "registered_at", str(int(time.time()))
    ]);
    return True;
}


def _feature_limit(feature: str) -> tuple[str, int] {
    mapping: dict[str, tuple[str, int]] = {
        "clothing-analysis": ("TYYLI_RATE_LIMIT_ANALYZE", 10),
        "outfit-recommendation": ("TYYLI_RATE_LIMIT_RECOMMEND", 10),
        "outfit-explanation": ("TYYLI_RATE_LIMIT_EXPLAIN", 10),
        "product-lookup": ("TYYLI_RATE_LIMIT_PRODUCT_LOOKUP", 10),
        "stylist-chat": ("TYYLI_RATE_LIMIT_CHAT", 30),
        "style-identity": ("TYYLI_RATE_LIMIT_STYLE_IDENTITY", 10)
    };
    return mapping[feature];
}


def _advance_assertion_counter(store_name: str, old_counter: int, new_counter: int) {
    script = (
        "local c=tonumber(redis.call('HGET',KEYS[1],'counter') or '-1');"
        "if c~=tonumber(ARGV[1]) then return 0 end;"
        "redis.call('HSET',KEYS[1],'counter',ARGV[2]);return 1"
    );
    updated = int(upstash_command([
        "EVAL", script, "1", store_name, str(old_counter), str(new_counter)
    ]));
    if updated != 1 {
        raise RuntimeError("The App Attest assertion counter was already used.");
    }
}


def:pub authorize_app_request(
    feature: str,
    key_id: str,
    challenge_id: str,
    assertion_data: str
) -> str {
    if feature not in _ALLOWED_FEATURES {
        raise ValueError("Unknown protected feature.");
    }
    record = _consume_challenge(challenge_id);
    if (
        record.get("kind") != "assertion"
        or record.get("key_hash") != _key_hash(key_id)
        or record.get("feature") != feature
    ) {
        raise RuntimeError("The App Attest assertion challenge does not match.");
    }
    store_name = _key_store_name(key_id);
    stored = _pairs_to_dict(upstash_command(["HGETALL", store_name]));
    if not stored.get("public_key") {
        raise RuntimeError("This App Attest key is not registered.");
    }
    challenge = str(record.get("challenge", ""));
    expected_hash = hashlib.sha256(challenge.encode("utf-8")).digest();
    (Assertion, _Attestation, AppleConfig, load_der_public_key) = _verifier_types();
    public_key = load_der_public_key(
        base64.b64decode(stored["public_key"].encode("ascii"))
    );
    config = AppleConfig(
        key_id=_decode_base64(key_id),
        app_id=_apple_app_id(),
        production=True
    );
    assertion = Assertion(
        _decode_base64(assertion_data), expected_hash, public_key, config
    );
    assertion.verify();
    data = assertion.data;
    expected_rp_id = hashlib.sha256(_apple_app_id().encode("utf-8")).digest();
    if data.get("rp_id") != expected_rp_id {
        raise RuntimeError("The App Attest assertion belongs to another app.");
    }
    old_counter = int(stored.get("counter", "0"));
    new_counter = int(data.get("counter", 0));
    if new_counter <= old_counter {
        raise RuntimeError("The App Attest assertion has already been used.");
    }
    _advance_assertion_counter(store_name, old_counter, new_counter);
    (limit_env, default_limit) = _feature_limit(feature);
    enforce_device_rate_limit(_key_hash(key_id), feature, limit_env, default_limit);
    enforce_global_daily_limit(
        "claude", "TYYLI_CLAUDE_GLOBAL_DAILY_LIMIT", 200
    );
    token = secrets.token_urlsafe(32);
    stored_token = upstash_command([
        "SET", _authorization_store_name(token), feature, "EX", "60", "NX"
    ]);
    if str(stored_token).upper() != "OK" {
        raise RuntimeError("Could not authorize the AI request.");
    }
    return "appattest:" + token;
}


def _consume_app_attest_authorization(credential: str, feature: str) {
    token = credential[len("appattest:"):];
    if not token {
        raise RuntimeError("The AI request is missing App Attest authorization.");
    }
    stored_feature = upstash_command([
        "GETDEL", _authorization_store_name(token)
    ]);
    if stored_feature != feature {
        raise RuntimeError("The AI authorization is invalid or expired.");
    }
}


def authorize_paid_feature(
    credential: str,
    feature: str,
    limit_env: str,
    default_limit: int
) {
    if credential.startswith("appattest:") {
        _consume_app_attest_authorization(credential, feature);
        return;
    }
    if _truthy_env("TYYLI_REQUIRE_APP_ATTEST", False) {
        raise RuntimeError(
            "This AI feature requires the TestFlight app on a supported iPhone."
        );
    }
    # Temporary compatibility path for Expo Go and earlier TestFlight builds.
    enforce_device_rate_limit(credential, feature, limit_env, default_limit);
    enforce_global_daily_limit(
        "claude", "TYYLI_CLAUDE_GLOBAL_DAILY_LIMIT", 200
    );
}
