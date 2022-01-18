datacenter = "us-west-2-aws"
data_dir = "/opt/services/consul/data"
log_level = "INFO"
node_name = "${node_name}"
server = true
bootstrap_expect = 3
bind_addr = "${node_ip}"
addresses = {
  https = "${node_ip}"
}
ports = {
  dns = -1
  http = -1
  https = 8501
  serf_wan = -1
}
ca_file = "/opt/services/certs/ca_chain.cert.pem"
cert_file = "/opt/services/certs/node.example.local.cert.pem"
key_file = "/opt/services/certs/node.example.local.key.pem"
server_name = "${node_name}.example.local"
verify_incoming = true
verify_outgoing = true
retry_join = ["${node_a_name}.example.local","${node_b_name}.example.local"]
