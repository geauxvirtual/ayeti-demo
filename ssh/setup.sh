#!/bin/bash

# Simple script that generates an SSH key pair with an email address of service_account@example.local

set -e

ssh-keygen -t rsa -C "service_account@example.local" -f ./service-account
