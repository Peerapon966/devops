variable "vault_address" {
  description = "Origin URL of the Vault server"
  type        = string
}

variable "kubernetes_address" {
  description = "Origin URL of the Kubernetes cluster"
  type        = string
}

variable "vault_ca_cert_file" {
  description = "Path to a CA file on local disk (relative to the root module) that will be used to validate the certificate presented by the Vault server"
  type        = string
  default     = "assets/cacert/vault-root-ca.crt"
}

variable "k8s_ca_cert_file" {
  description = "Path to a CA file on local disk (relative to the root module) that will be used to validate the certificate presented by the Kubernetes cluster"
  type        = string
  default     = "assets/cacert/k8s-root-ca.crt"
}

variable "token_reviewer_jwt" {
  description = "JWT token to pass to Vault for validating service account token presented by the Kubernetes cluster"
  type        = string
}
