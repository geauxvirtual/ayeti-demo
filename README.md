Hashicorp 3 node Vault and Consul setup.

TODO: Document all steps to run what in this repo.

This repo consists of Terraform and Packer configurations to build and deploy an AMI capable
of running Vault and Consul securely, or at least more secure than just running in an unsecure dev
setup.

Below are the manual steps after `terraform apply` is run and deploys out the three cluster nodes.

Initialize Vault with a single recovery key for demo purposes.

```
vault operator init -recovery-shares=1 -recovery-threshold=1 > key.txt
```

Login to Vault with root token

```
vault login $(grep 'Initial Root Token:' key.txt | awk '{print $NF}')
```

Enable and configure the PKI secrets engine (https://www.vaultproject.io/docs/secrets/pki)
```
vault secrets enable pki
```

```
vault secrets tune -max-lease-ttl=87600h pki
```

For our demo purposes, Vault will be configured with as an Intermediate CA. A CSR will be generated
and signed by the Intermediate CA created outside of Vault that signed all the certificates securing
Vault and Consul.

```
vault write pki/intermediate/generate/internal common_name="Demo Vault Intermediate Certificate Authority" ttl=43800h
```

Copy the CSR to a certificate on the local dev laptop where the Intermediate CA exists and sign it. Copy the signed cert back to Vault.

Import signed cert into Vault.

```
vault write pki/intermediate/set-signed certificate=@vault.intermediate.cert.pem
```

Create a role for the Demo that will generate certificates with a 5m TTL.
```
vault write pki/roles/example-local allowed_domains="example.local" allow_subdomains=true max_ttl="5m"
```


