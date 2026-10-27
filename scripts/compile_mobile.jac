"""Compile the Jac mobile client without starting a native platform build."""
import from pathlib { Path }
import from jaclang.runtime.runtime { JacRuntime as Jac }
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
    write_native_entry
}


with entry {
    project_dir = Path(__file__).resolve().parent.parent;
    entry_file = project_dir / "main.jac";
    rn_dir = resolve_rn_project_dir(project_dir);
    api_shim = rn_dir / "__jacApiBase.js";
    # Jac's native entry writer recreates this file. Keep an already-injected
    # device-visible API URL so a later client rebuild cannot silently turn
    # server calls into relative requests against Metro.
    existing_api_shim = api_shim.read_text(encoding="utf-8") if api_shim.exists() else "";

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
    if "globalThis.__JAC_API_BASE_URL__ =" in existing_api_shim {
        api_shim.write_text(existing_api_shim, encoding="utf-8");
    }
    print("Jac mobile client compiled.");
}
