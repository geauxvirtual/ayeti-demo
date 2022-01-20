#!/bin/bash

# This script is for setting up the directory structure, generating the RootCA, generating the Intermediate CA, 
# and generating the node certificates.

set -e

function setup_base_dirs {
    mkdir certs crl csr newcerts private
    chmod 700 private
}

function setup_required_files {
    touch index.txt
    echo 1000 > serial
}

# Check if openssl is installed
if hash openssl 2>/dev/null; then
    echo "Openssl installed. Proceeding"
else
    echo "Openssl not installed. Please install and run setup.sh again."
    exit 1
fi

# Verify this is being run from the correct directory
if [ ! -f "openssl.cnf" ]; then
    echo "openssl.cnf missing"
    exit 1
fi

if [ ! -f "intermediate/openssl.cnf" ]; then
    echo "intermediate/openssl.cnf missing"
    exit 1
fi

if [ ! -f "intermediate/node.cnf" ]; then
    echo "intermediate/node.cnf missing"
    exit 1
fi

# Setup up directory structure under tls/root/ca
setup_base_dirs
setup_required_files

# Make intermediate directory under tls/root/ca
cd intermediate
# Setup directory structure under tls/root/ca/intermediate
setup_base_dirs
setup_required_files
echo 1000 > crlnumber
cd ..

# Generate our RootCA private key
openssl genrsa -aes256 -out private/ca.key.pem 4096
chmod 400 private/ca.key.pem

# Generate our RootCA certificates
openssl req -config openssl.cnf \
    -key private/ca.key.pem \
    -new -x509 -days 7300 -sha256 -extensions v3_ca \
    -out certs/ca.cert.pem
chmod 444 certs/ca.cert.pem

# Generate Intermediate CA private key
openssl genrsa -aes256 \
    -out intermediate/private/intermediate.key.pem 4096
chmod 400 intermediate/private/intermediate.key.pem

# Generate Intermedate CA csr
openssl req -config intermediate/openssl.cnf -new -sha256 \
    -key intermediate/private/intermediate.key.pem \
    -out intermediate/csr/intermediate.csr.pem

# Sign Intermediate CA csr
openssl ca -config openssl.cnf -extensions v3_intermediate_ca \
    -days 3650 -notext -md sha256 \
    -in intermediate/csr/intermediate.csr.pem \
    -out intermediate/certs/intermediate.cert.pem
chmod 444 intermediate/certs/intermediate.cert.pem

# Chain the RootCA with the Intermediate CA
cat intermediate/certs/intermediate.cert.pem certs/ca.cert.pem > intermediate/certs/ca-chain.cert.pem
chmod 444 intermediate/certs/ca-chain.cert.pem

# Generate node private key
openssl genrsa -out intermediate/private/node.example.local.key.pem 2048
chmod 400 intermediate/private/node.example.local.key.pem

# Generate node csr
openssl req -config intermediate/node.cnf \
    -key intermediate/private/node.example.local.key.pem \
    -new -sha256 \
    -out intermediate/csr/node.example.local.csr.pem

# Sign node csr with Intermediate CA
openssl ca -config intermediate/openssl.cnf -extensions server_cert \
    -extensions req_ext -extfile intermediate/node.cnf \
    -days 375 -notext -md sha256 \
    -in intermediate/csr/node.example.local.csr.pem \
    -out intermediate/certs/node.example.local.cert.pem
