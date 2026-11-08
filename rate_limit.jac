"""Best-effort per-installation limits for paid server features.

The mobile app sends a random installation id with each paid RPC. Only a hash
of that id is kept in memory, and counters expire after the configured window.
This is intentionally lightweight for the single-instance MVP deployment.
"""
import hashlib;
import os;
import time;
import from threading { Lock }


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


def enforce_device_rate_limit(
    device_id: str,
    feature: str,
    limit_env: str,
    default_limit: int
) {
    limit = _positive_env_int(limit_env, default_limit);
    window_seconds = _positive_env_int("TYYLI_RATE_LIMIT_WINDOW_SECONDS", 3600);
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


def reset_rate_limits_for_tests {
    with _RATE_LOCK {
        _RATE_BUCKETS.clear();
    }
}
