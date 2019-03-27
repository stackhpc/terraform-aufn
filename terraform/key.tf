resource "tls_private_key" "lab" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

