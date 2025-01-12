provider "kubernetes" {
  config_path = "~/.kube/config-aws"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config-aws"
  }
}

resource "kubernetes_namespace" "jfrog" {
  metadata {
    name = "jfrog"
  }
}

resource "kubernetes_secret" "www2_cert" {
  metadata {
    name = "www2-cert"
  }

  type = "tls"

  data = {
    "tls.crt" = data.terraform_remote_state.certificate.outputs.www2_certificate
    "tls.key" = data.terraform_remote_state.certificate.outputs.www2_private_key
  }
}

resource "kubernetes_secret" "jfrog_cert" {
  metadata {
    name      = "jfrog-cert"
    namespace = "jfrog"
  }

  type = "tls"

  data = {
    "tls.crt" = data.terraform_remote_state.certificate.outputs.jfrog_certificate
    "tls.key" = data.terraform_remote_state.certificate.outputs.jfrog_private_key
  }

  depends_on = [kubernetes_namespace.jfrog]
}

resource "null_resource" "get_rook-ceph-operator-values" {
  provisioner "local-exec" {
    command = <<EOF
curl -s -o /tmp/rook-ceph-operator-values.yaml https://raw.githubusercontent.com/rook/rook/refs/heads/master/deploy/charts/rook-ceph/values.yaml
sed -i -e 's/cpu:.*/cpu:/' /tmp/rook-ceph-operator-values.yaml
sed -i -e 's/memory:.*/memory:/' /tmp/rook-ceph-operator-values.yaml
    EOF
  }
}

resource "null_resource" "get_rook-ceph-cluster-values" {
  provisioner "local-exec" {
    command = <<EOF
curl -s -o /tmp/rook-ceph-cluster-values.yaml https://raw.githubusercontent.com/rook/rook/refs/heads/master/deploy/charts/rook-ceph-cluster/values.yaml
sed -i -e 's/cpu:.*/cpu:/' /tmp/rook-ceph-cluster-values.yaml
sed -i -e 's/memory:.*/memory:/' /tmp/rook-ceph-cluster-values.yaml
    EOF
  }

  depends_on = [null_resource.get_rook-ceph-operator-values]
}

resource "helm_release" "rook-ceph-operator" {
  name             = "rook-ceph"
  repository       = "https://charts.rook.io/release"
  chart            = "rook-ceph"
  namespace        = "rook-ceph"
  create_namespace = true
  force_update     = true

  values = [
    "${file("/tmp/rook-ceph-operator-values.yaml")}"
  ]

  depends_on = [null_resource.get_rook-ceph-cluster-values]
}

resource "helm_release" "rook-ceph-cluster" {
  name             = "rook-ceph-cluster"
  repository       = "https://charts.rook.io/release"
  chart            = "rook-ceph-cluster"
  namespace        = "rook-ceph"
  create_namespace = true
  force_update     = true

  values = [
    "${file("/tmp/rook-ceph-cluster-values.yaml")}"
  ]

  set {
    name  = "toolbox.enabled"
    value = "true"
  }
  set {
    name  = "cephFileSystems[0].storageClass.enabled"
    value = "false"
  }
  set {
    name  = "cephObjectStores[0].storageClass.enabled"
    value = "false"
  }

  depends_on = [helm_release.rook-ceph-operator]
}
