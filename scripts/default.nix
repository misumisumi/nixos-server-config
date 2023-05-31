{
  callPackage,
  writeShellScriptBin,
  jq,
  kubectl,
  nixos-generators,
  terraform,
}: {
  check_k8s = callPackage (import ./check_k8s.nix) {};
  deploy = callPackage (import ./deploy.nix) {};
  mkenv = callPackage (import ./mkenv.nix) {};
  ter = writeShellScriptBin "ter" ''
    ${terraform}/bin/terraform $@ && \
      ${terraform}/bin/terraform show -json | ${jq}/bin/jq > show.json
  '';
  k = writeShellScriptBin "k" ''
    ${kubectl}/bin/kubectl --kubeconfig certs/generated/kubernetes/admin.kubeconfig $@
  '';
  mkimg4lxc = writeShellScriptBin "mkimg4lxc" ''
    lxc image import --alias nixos ''$(${nixos-generators}/bin/nixos-generate -f lxc-metadata) ''$(${nixos-generators}/bin/nixos-generate -f lxc --flake ".#terraform-lxc")
  '';
}