"""Start Expo Metro with the JavaScript runtime bundled by Jac."""
import os;
import from pathlib { Path }
import from jaclang.client.targets.react_native.common { resolve_rn_project_dir }
import from jaclang.client.targets.react_native.dev { run_expo_start }


with entry {
    project_dir = Path(__file__).resolve().parent.parent;
    rn_dir = resolve_rn_project_dir(project_dir);
    metro_port = int(os.environ.get("JAC_RN_METRO_PORT", "8081"));
    result = run_expo_start(rn_dir, metro_port, clear_cache=True);
    if result != 0 {
        raise RuntimeError("Expo Metro exited with code " + str(result) + ".");
    }
}
