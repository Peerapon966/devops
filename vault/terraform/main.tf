resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
}

resource "vault_kubernetes_auth_backend_config" "example" {
  backend                           = vault_auth_backend.kubernetes.path
  kubernetes_host                   = var.kubernetes_address
  kubernetes_ca_cert                = file("${path.root}/${var.k8s_ca_cert_file}")
  token_reviewer_jwt                = var.token_reviewer_jwt
  disable_local_ca_jwt              = false
  disable_iss_validation            = true
  use_annotations_as_alias_metadata = false
}
