"""Tyyli mobile app entry point."""
import from .storage_test { StorageTestScreen }


def:pub app -> JsxElement {
    # `jac run --dev` injects the current developer machine's API URL.
    return <StorageTestScreen/>;
}
