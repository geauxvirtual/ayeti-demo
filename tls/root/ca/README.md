This folder is for configuring a RootCA that can sign an Intermediate CA which can used to sign other Intermediate CA CSR requests along with node CSRs.

1. If needed, update the `dir` field in openssl.cnf and `intermediate/openssl.cnf`
2. If needed, update the node dns names and IPs in `intermediate/node.cnf`
3. Run `./setup.sh`
