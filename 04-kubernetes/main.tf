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

resource "helm_release" "longhorn" {
  name             = "longhorn"
  repository       = "https://charts.longhorn.io"
  chart            = "longhorn"
  namespace        = "longhorn-system"
  create_namespace = true
  force_update     = true
}
