reload_signal = "SIGHUP"
kill_signal = "SIGINT"

vault {
  address = "https://${vault_addr}:8200"
  vault_agent_token_file = "/tmp/vault_token"
  renew_token = true
  ssl {
    enabled = true
    verify = true
    ca_cert = "/opt/services/certs/ca_chain.cert.pem"
    cert = "/opt/services/certs/node.example.local.cert.pem"
    key = "/opt/services/certs/node.example.local.key.pem"
  }
}

template {
  contents = "{{ with secret \"pki/issue/example-local\" \"ttl=5m\" \"common_name=${fqdn}\" \"ip_sans=10.0.1.20\"}}{{ .Data.certificate }}{{ end }}"
  destination = "/etc/nginx/web.example.local.cert.pem"
  command = "systemctl restart nginx"
}

template {
  contents = "{{ with secret \"pki/issue/example-local\" \"ttl=5m\" \"common_name=${fqdn}\" \"ip_sans=10.0.1.20\"}}{{ .Data.private_key }}{{ end }}"
  destination = "/etc/nginx/web.example.local.key.pem"
  command = "systemctl restart nginx"
}


