{
  lib,
  pkgs,
  cfssl,
  kubectl,
}: let
  inherit (pkgs.callPackage ../src/resources.nix {}) resourcesByRole;
  inherit (import ../src/consts.nix) virtualIP;
  inherit (import ../src/utils.nix) nodeIP;
  inherit (pkgs.callPackage ./src/utils.nix {}) getAltNames mkCsr;

  caCsr = mkCsr "kubernetes-ca" {
    cn = "kubernetes-ca";
  };

  apiServerCsr = mkCsr "kube-api-server" {
    cn = "kubernetes";
    altNames =
      lib.singleton virtualIP
      ++
      # Alternative names remain, as they might be useful for debugging purposes
      getAltNames "controlplane"
      ++ getAltNames "loadbalancer"
      ++ ["kubernetes" "kubernetes.default" "kubernetes.default.svc" "kubernetes.default.svc.cluster" "kubernetes.svc.cluster.local"];
  };

  apiServerKubeletClientCsr = mkCsr "kube-api-server-kubelet-client" {
    cn = "kube-api-server";
    altNames = getAltNames "controlplane";
    organizationUnit = "system:masters";
  };

  cmCsr = mkCsr "kube-controller-manager" {
    cn = "system:kube-controller-manager";
    organizationUnit = "system:kube-controller-manager";
  };

  adminCsr = mkCsr "admin" {
    cn = "admin";
    organizationUnit = "system:masters";
  };

  etcdClientCsr = mkCsr "etcd-client" {
    cn = "kubernetes";
    altNames = getAltNames "controlplane";
  };

  kubeletCsr = mkCsr "kubelet" {
    cn = "kubelet";
  };

  proxyCsr = mkCsr "kube-proxy" {
    cn = "system:kube-proxy";
    organizationUnit = "system:node-proxier";
  };

  schedulerCsr = mkCsr "kube-scheduler" rec {
    cn = "system:kube-scheduler";
    organizationUnit = cn;
  };

  workerCsrs =
    map
    (r: {
      name = r.values.name;
      csr = mkCsr r.values.name {
        cn = "system:node:${r.values.name}";
        organizationUnit = "system:nodes";
        # TODO: unify with getAltNames?
        altNames = [r.values.name (nodeIP r)];
      };
    })
    (resourcesByRole "worker");

  workerScripts = map (csr: "genCert peer kubelet/${csr.name} ${csr.csr}") workerCsrs;
in ''
  mkdir -p $out/kubernetes/{apiserver,controller-manager,kubelet}

  pushd $out/etcd > /dev/null
  genCert client ../kubernetes/apiserver/etcd-client ${etcdClientCsr}
  popd > /dev/null

  pushd $out/kubernetes > /dev/null

  genCa ${caCsr}
  genCert server apiserver/server ${apiServerCsr}
  genCert server apiserver/kubelet-client ${apiServerKubeletClientCsr}
  genCert client controller-manager ${cmCsr}
  genCert client proxy ${proxyCsr}
  genCert client scheduler ${schedulerCsr}
  genCert client admin ${adminCsr}

  ${builtins.concatStringsSep "\n" workerScripts}

  ${kubectl}/bin/kubectl --kubeconfig admin.kubeconfig config set-credentials admin \
      --client-certificate=admin.pem \
      --client-key=admin-key.pem
  ${kubectl}/bin/kubectl --kubeconfig admin.kubeconfig config set-cluster lxd \
      --certificate-authority=ca.pem \
      --server=https://${virtualIP}
  ${kubectl}/bin/kubectl --kubeconfig admin.kubeconfig config set-context lxd \
      --user admin \
      --cluster lxd
  ${kubectl}/bin/kubectl --kubeconfig admin.kubeconfig config use-context lxd > /dev/null

  popd > /dev/null
''