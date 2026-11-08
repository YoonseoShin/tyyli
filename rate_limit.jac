"""Per-installation limits for paid server features.

Production counters live in Upstash so restarts and multiple Render instances
cannot reset them. Local development keeps the bounded in-memory fallback.
Only SHA-256 hashes of installation or App Attest key identifiers are stored.
"""
import hashlib;
import json;
import os;
import time;
import from threading { Lock }
import from urllib.request { Request, urlopen }


glob _RATE_BUCKETS: dict[str, list[float]] = {},
     _RATE_LOCK = Lock(),
     _MAX_RATE_BUCKETS: int = 10000;


def _positive_env_int(name: str, fallback: int) -> int {
    try {
        value = int(os.environ.get(name, str(fallback)));
        return value if value > 0 else fallback;
    } except Exception {
        return fallback;
    }
}


def _bucket_key(feature: str, device_id: str) -> str {
    installation = device_id.strip() or "legacy-client";
    digest = hashlib.sha256(installation.encode("utf-8")).hexdigest();
    return feature + ":" + digest;
}


def upstash_configured -> bool {
    return bool(
        os.environ.get("UPSTASH_REDIS_REST_URL", "").strip()
        and os.environ.get("UPSTASH_REDIS_REST_TOKEN", "").strip()
    );
}


def upstash_command(command: list[any]) -> any {
    url = os.environ.get("UPSTASH_REDIS_REST_URL", "").strip().rstrip("/");
    token = os.environ.get("UPSTASH_REDIS_REST_TOKEN", "").strip();
    if not url or not token {
        raise RuntimeError("Persistent rate-limit storage is not configured.");
    }
    request = Request(
        url,
        data=json.dumps(command).encode("utf-8"),
        headers={
            "Authorization": "Bearer " + token,
            "Content-Type": "application/json"
        },
        method="POST"
    );
    with urlopen(request, timeout=10) as response {
        result = json.loads(response.read().decode("utf-8")) as dict[str, any];
    }
    if result.get("error") {
        raise RuntimeError("Persistent rate-limit storage rejected a command.");
    }
    return result.get("result");
}


def _persistent_fixed_window_limit(
    identity_hash: str,
    feature: str,
    limit: int,
    window_seconds: int
) {
    window = int(time.time()) // window_seconds;
    key = "tyyli:rate:" + feature + ":" + identity_hash + ":" + str(window);
    script = (
        "local n=redis.call('INCR',KEYS[1]);"
        "if n==1 then redis.call('EXPIRE',KEYS[1],ARGV[1]) end;"
        "return n"
    );
    count = int(upstash_command([
        "EVAL", script, "1", key, str(window_seconds + 60)
    ]));
    if count > limit {
        raise RuntimeError(
            "This device has reached the usage limit for this feature. "
            "Please try again after the current usage window resets."
        );
    }
}


def enforce_device_rate_limit(
    device_id: str,
    feature: str,
    limit_env: str,
    default_limit: int
) {
    limit = _positive_env_int(limit_env, default_limit);
    window_seconds = _positive_env_int("TYYLI_RATE_LIMIT_WINDOW_SECONDS", 3600);
    identity = device_id.strip() or "legacy-client";
    digest = hashlib.sha256(identity.encode("utf-8")).hexdigest();
    if upstash_configured() {
        _persistent_fixed_window_limit(digest, feature, limit, window_seconds);
        return;
    }
    now = time.time();
    cutoff = now - float(window_seconds);
    key = _bucket_key(feature, device_id);
    with _RATE_LOCK {
        # Keep memory bounded if arbitrary ids are sent to the public endpoint.
        if key not in _RATE_BUCKETS and len(_RATE_BUCKETS) >= _MAX_RATE_BUCKETS {
            key = feature + ":overflow";
        }
        recent = [stamp for stamp in _RATE_BUCKETS.get(key, []) if stamp > cutoff];
        if len(recent) >= limit {
            retry_seconds = max(1, int(recent[0] + float(window_seconds) - now) + 1);
            retry_minutes = max(1, (retry_seconds + 59) // 60);
            _RATE_BUCKETS[key] = recent;
            raise RuntimeError(
                "This device has reached the usage limit for this feature. "
                "Please try again in about " + str(retry_minutes) + " minute"
                + ("s." if retry_minutes != 1 else ".")
            );
        }
        recent.append(now);
        _RATE_BUCKETS[key] = recent;
    }
}


def enforce_global_daily_limit(feature: str, limit_env: str, default_limit: int) {
    limit = _positive_env_int(limit_env, default_limit);
    if not upstash_configured() {
        # Local development has no shared billable deployment to protect.
        return;
    }
    day = int(time.time()) // 86400;
    key = "tyyli:global:" + feature + ":" + str(day);
    script = (
        "local n=redis.call('INCR',KEYS[1]);"
        "if n==1 then redis.call('EXPIRE',KEYS[1],ARGV[1]) end;"
        "return n"
    );
    count = int(upstash_command(["EVAL", script, "1", key, "90000"]));
    if count > limit {
        raise RuntimeError(
            "The AI service has reached today's shared safety limit. "
            "Please try again tomorrow."
        );
    }
}


def reset_rate_limits_for_tests {
    with _RATE_LOCK {
        _RATE_BUCKETS.clear();
    }
}
