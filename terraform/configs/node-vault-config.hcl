storage "consul" {
  address = "${node_ip}:8501"
  path = "vault"
  scheme = "https"
  tls_ca_file = "/opt/services/certs/ca_chain.cert.pem"
  tls_cert_file = "/opt/services/certs/node.example.local.cert.pem"
  tls_key_file = "/opt/services/certs/node.example.local.key.pem"
}

listener "tcp" {
  address = "${node_ip}:8200"
  tls_cert_file = "/opt/services/certs/node.example.local.cert.pem"
  tls_key_file = "/opt/services/certs/node.example.local.key.pem"
  tls_require_and_verify_client_cert = true
  tls_client_ca_file = "/opt/services/certs/ca_chain.cert.pem"
}

cluster_name = "Vault-Demo-1"
api_addr = "https://${fqdn}:8200"
cluster_addr = "https://${fqdn}:8201"

seal "awskms" {
  region = "${region}"
  kms_key_id = "${aws_kms_key}"
}
