{lib, ...}: let
  pwd = builtins.getEnv "PWD";
  json = "${builtins.getEnv "PWD"}/show.json";
  payload =
    if builtins.pathExists json
    then builtins.fromJSON (builtins.readFile json)
    else {};
  resourcesInModule = type: module: builtins.filter (r: r.type == type) (module.resources or []) ++ lib.flatten (map (resourcesInModule type) (module.child_modules or []));
  resourcesByType = type: resourcesInModule type (payload.values.root_module or []);
in rec {
  resources = resourcesByType "lxd_container";
  resourcesByRole = role: (builtins.filter (r: lib.strings.hasPrefix role r.values.name) resources);
  resourcesByRoles = roles: lib.flatten (lib.forEach roles (role: builtins.filter (r: lib.strings.hasPrefix role r.values.name) resources));
}