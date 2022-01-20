Hashicorp 3 node Vault and Consul setup.

TODO: Document all steps to run what in this repo.

1. Setup RootCA, generate and sign Intermediate CA, then generate and sign node certificate. For simplicity sake, same node certificate is used for all three nodes. The DNS names and IPs are configured in the certificate.

2. Generate SSH key pair. The public key will be added to the deployed nodes to allow SSH access.

3. Run `terraform init` in terraform directory.

4. Run `terraform validate`

5. Run `terraform apply`

This repo consists of Terraform and Packer configurations to build and deploy an AMI capable
of running Vault and Consul securely, or at least more secure than just running in an unsecure dev
setup.

Below are the manual steps after `terraform apply` is run from the terraform directory and deploys out the three cluster nodes.

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

For the demo, a web service needs a certificate renewed every 5m or so. On the web service instance
consul-template is running that will handle generating a new certificating, installing it, and restarting the nginx service. Consul-template needs a Vault token and appropriate rights to generate a certificate.

Create a pki.hcl file with the following settings.
```
path "pki/isssue/example-local" {
  capabilities = ["update"]
}
```

Create a Vault token for the demo. For the demo, we'll just create a token, store it in a i`.vault_token` file in the terraform-web directory to be read by terraform, and created in the /tmp directory of the web service. A better solution would be to store the token in AWS and give the instance approrpriate rights to read the token such as what is done with awskms seal/unseal solution.
```
vault token craate -policy="pki" -period=96h -orphan
```

In order to not duplicate resources or create new network resources, we use the VPC and subnet ids created initially when creating networking for the web service. For this, we're are reading the terraform.tfstate file from the terraform directory for the vpc_id and demo_subnet_id outputs.

Run the following to deploy the web services from the terraform-web directory
```
terraform init
terraform validate
terraform apply
```

The nodes have statically assigned IP addresses and dns names.
node1.example.local - 10.0.1.10
node2.example.local - 10.0.1.11
node3.example.local - 10.0.1.12
web.example.local   - 10.0.1.20

