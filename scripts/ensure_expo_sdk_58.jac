"""Keep the generated React Native project compatible with Expo Go SDK 58."""
import json;
import from pathlib { Path }
import from jaclang.client.targets.react_native.common {
    resolve_rn_project_dir,
    run_manifest_install
}


glob SDK_58_DEPENDENCIES = {
    "expo": "~58.0.19",
    "expo-asset": "~58.0.18",
    "expo-constants": "~58.0.13",
    "expo-file-system": "~58.0.11",
    "expo-image-manipulator": "~58.0.15",
    "expo-image-picker": "~58.0.10",
    "expo-location": "~58.0.19",
    "expo-secure-store": "~58.0.2",
    "expo-sqlite": "~58.0.14",
    "expo-status-bar": "~58.0.4",
    "react": "19.3.0",
    "react-native": "0.88.0",
    "react-native-gesture-handler": "~3.3.0",
    "react-native-safe-area-context": "~5.10.1",
    "react-native-screens": "~4.30.0",
    "@expo/vector-icons": "^15.0.2",
    "@react-native-async-storage/async-storage": "2.2.0"
},
SDK_58_DEV_DEPENDENCIES = {
    "babel-preset-expo": "~58.0.20",
    "@types/react": "~19.3.0",
    "typescript": "~6.0.3"
};


with entry {
    project_dir = Path(__file__).resolve().parent.parent;
    rn_dir = resolve_rn_project_dir(project_dir);
    package_path = rn_dir / "package.json";

    if not package_path.exists() {
        raise RuntimeError(
            "Expo project not found. Run 'jac setup' before starting mobile development."
        );
    }

    package_data = json.loads(package_path.read_text(encoding="utf-8"));
    dependencies = package_data.get("dependencies", {});
    dev_dependencies = package_data.get("devDependencies", {});
    changed = False;

    for (name, version) in SDK_58_DEPENDENCIES.items() {
        if dependencies.get(name) != version {
            dependencies[name] = version;
            changed = True;
        }
    }
    for (name, version) in SDK_58_DEV_DEPENDENCIES.items() {
        if dev_dependencies.get(name) != version {
            dev_dependencies[name] = version;
            changed = True;
        }
    }

    package_data["dependencies"] = dependencies;
    package_data["devDependencies"] = dev_dependencies;
    if changed {
        package_path.write_text(
            json.dumps(package_data, indent=2) + "\n",
            encoding="utf-8"
        );
    }

    installed_expo_path = rn_dir / "node_modules" / "expo" / "package.json";
    installed_expo_version = "";
    if installed_expo_path.exists() {
        installed_expo = json.loads(
            installed_expo_path.read_text(encoding="utf-8")
        );
        installed_expo_version = str(installed_expo.get("version", ""));
    }

    if changed or not installed_expo_version.startswith("58.") {
        print("Updating the generated mobile project to Expo SDK 58...");
        run_manifest_install(rn_dir);
        print("Expo SDK 58 dependencies installed.");
    } else {
        print("Expo SDK 58 dependencies are ready.");
    }
}
