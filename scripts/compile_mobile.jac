"""Compile the Jac mobile client without starting a native platform build."""
import json;
import os;
import from pathlib { Path }
import from jaclang.runtime.runtime { JacRuntime as Jac }
import from jaclang.client.config_loader { JacClientConfig }
import from jaclang.client.vite_client_bundle { ViteClientBundleBuilder }
import from jaclang.client.targets.react_native.common { resolve_rn_project_dir }
import from jaclang.client.targets.react_native.build {
    entry_module_for,
    lint_native_incompatible_usage,
    lint_unmapped_tags,
    read_user_js_sources,
    stage_compiled_entry,
    stage_native_image_assets,
    strip_css_imports,
    write_api_base_shim,
    write_native_entry
}


with entry {
    project_dir = Path(__file__).resolve().parent.parent;
    entry_file = project_dir / "main.jac";
    rn_dir = resolve_rn_project_dir(project_dir);
    client_config = JacClientConfig(project_dir);
    api_url = str(client_config.get_api_config().get("base_url", "")).rstrip("/");

    builder = Jac.get_client_bundle_builder();
    if not isinstance(builder, ViteClientBundleBuilder) {
        raise RuntimeError("Jac client compiler is unavailable.");
    }

    vite_compiler = builder._get_compiler();
    compiler = vite_compiler.jac_client_compiler;
    compiled_dir = compiler.compiled_dir;
    if compiled_dir is None {
        raise RuntimeError("Jac client output directory is unavailable.");
    }

    compiled_dir.mkdir(parents=True, exist_ok=True);
    compiler.compile(None, entry_file, native=True);
    js_sources = read_user_js_sources(compiled_dir);
    lint_unmapped_tags(compiled_dir, sources=js_sources);
    lint_native_incompatible_usage(compiled_dir, sources=js_sources);
    strip_css_imports(compiled_dir);
    stage_compiled_entry(
        compiled_dir,
        rn_dir,
        entry_module_for(entry_file, project_dir)
    );
    stage_native_image_assets(rn_dir / "jac-src", rn_dir);
    write_native_entry(rn_dir);
    write_api_base_shim(rn_dir, api_url);

    # Keep release metadata in the generated Expo project. The development
    # launcher overwrites the API shim with the Mac's LAN URL after this step,
    # while standalone/TestFlight builds keep the HTTPS production URL.
    app_path = rn_dir / "app.json";
    if app_path.exists() {
        app_data = json.loads(app_path.read_text(encoding="utf-8"));
        expo = app_data.get("expo", {});
        expo["name"] = "Tyyli";
        expo["slug"] = "tyyli";
        expo["version"] = "1.0.0";
        expo["owner"] = os.environ.get(
            "TYYLI_EXPO_OWNER", "tyyli-apps-team"
        );

        ios = expo.get("ios", {});
        ios["supportsTablet"] = False;
        ios["bundleIdentifier"] = os.environ.get(
            "TYYLI_IOS_BUNDLE_ID", "com.yoonseoshin.tyyli"
        );
        ios_config = ios.get("config", {});
        ios_config["usesNonExemptEncryption"] = False;
        ios["config"] = ios_config;
        ios_entitlements = ios.get("entitlements", {});
        ios_entitlements[
            "com.apple.developer.devicecheck.appattest-environment"
        ] = "production";
        ios["entitlements"] = ios_entitlements;
        expo["ios"] = ios;

        android = expo.get("android", {});
        android["package"] = os.environ.get(
            "TYYLI_ANDROID_PACKAGE", "com.yoonseoshin.tyyli"
        );
        expo["android"] = android;

        plugins = expo.get("plugins", []);
        for plugin_name in ["expo-asset", "expo-font", "expo-sqlite"] {
            if plugin_name not in plugins {
                plugins.append(plugin_name);
            }
        }
        expo["plugins"] = plugins;

        extra = expo.get("extra", {});
        extra["apiBaseUrl"] = api_url;
        eas = extra.get("eas", {});
        eas["projectId"] = os.environ.get(
            "TYYLI_EAS_PROJECT_ID", "81e2e778-ddb9-408b-bfb7-702b3baa64e4"
        );
        extra["eas"] = eas;
        expo["extra"] = extra;
        app_data["expo"] = expo;
        app_path.write_text(
            json.dumps(app_data, indent=2) + "\n",
            encoding="utf-8"
        );
    }

    eas_path = rn_dir / "eas.json";
    if eas_path.exists() {
        eas_data = json.loads(eas_path.read_text(encoding="utf-8"));
        cli = eas_data.get("cli", {});
        cli["appVersionSource"] = "remote";
        eas_data["cli"] = cli;
        builds = eas_data.get("build", {});
        production = builds.get("production", {});
        production["autoIncrement"] = True;
        builds["production"] = production;
        eas_data["build"] = builds;
        submissions = eas_data.get("submit", {});
        submit_production = submissions.get("production", {});
        submit_ios = submit_production.get("ios", {});
        submit_ios["ascAppId"] = os.environ.get(
            "TYYLI_ASC_APP_ID",
            "6829900708"
        );
        submit_production["ios"] = submit_ios;
        submissions["production"] = submit_production;
        eas_data["submit"] = submissions;
        eas_path.write_text(
            json.dumps(eas_data, indent=2) + "\n",
            encoding="utf-8"
        );
    }

    # The scaffold's .gitignore excludes compiled Jac sources, which is right
    # for Git but would make an EAS cloud build upload an empty app. EAS uses
    # this dedicated ignore file and therefore includes jac-src/jac-assets.
    (rn_dir / ".easignore").write_text(
        "node_modules/\n"
        ".expo/\n"
        "dist/\n"
        "web-build/\n"
        "android/\n"
        "ios/\n"
        "*.tsbuildinfo\n"
        ".DS_Store\n",
        encoding="utf-8"
    );
    print("Jac mobile client compiled.");
}
