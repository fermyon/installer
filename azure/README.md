# Azure README

This guide illustrates how to install Fermyon on Azure using Terraform.

If you are more of a visual learner, you can also checkout the [Getting Started with Fermyon on Azure video](https://youtu.be/d0XX0L1wYc0). 

As such, this is intended solely for evaluation and/or demo scenarios, i.e.
_not_ for production.

All Hashistack (Nomad, Consul, Vault), Traefik and Fermyon platform processes run
without any redundancy on a single Azure VM instance. There is no data backup for any
service.

That being said, it should give users a quick look and feel for deploying apps
using Fermyon. By default, all apps will be accessible to the broader internet
(see the configuration details mentioned below). Additionally, when Let's Encrypt
is enabled, apps will be provided with https URLs and TLS certs.

# Prerequisites

- An Azure account

  Terraform, by default, will use the subscription you are signed into via the [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli). For more information, check out Terraform's Docs for [Authentication using the Azure CLI](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/azure_cli)

  - The credentials needed by Terraform can also be provided via env vars:

    ```console
      export ARM_SUBSCRIPTION_ID=xxx
      export ARM_TENANT_ID=xxx
      export ARM_CLIENT_ID=xxx
      export ARM_CLIENT_SECRET=xxx
    ```

  - Or via local [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
    configuration (see `~/.azure/config`)

- The [terraform CLI](https://learn.hashicorp.com/tutorials/terraform/install-cli#install-terraform)

# Resources deployed

This example creates the following resources in the provided Azure account:

- 1 Azure VM (default size: `Standard_DS1_v2`)
  - Name: `${var.vm_name}`
- 1 Public IP address (associated with virtual machine)
  - Name: `${var.vm_name}-pip`
  - This is useful as it won't change with virtual machine reboots and is a known
    value for constructing Hippo and Bindle URLs
- 1 Network Security Group
  - Name: `${var.vm_name}-nsg`
  - Inbound connections allowed for ports 22, 80 and 443
    - see `var.allowed_inbound_cidr_blocks` for allowed origin IP addresses
  - All outbound connections allowed
- 1 Virtual Network
  - Name: `${var.vm_name}-vnet`
- 1 Regular Network Interface (associated with virtual machine and public IP address)
  - Name: `${var.vm_name}-nic`
- 1 Storage Account
  - Name: `${var.vm_name}-storage`
  - This is used to store diagnostics logs for the VM
- 1 Disk
  - Name: `${var.vm_name}-disk`
  - Attached to virtual machine
- 1 SSH Key
  - Name: `${var.vm_name}_ssh_public_key`
  - see `var.allowed_ssh_cidr_blocks` for allowed origin IP addresses

> All resources are tagged with a common set of tags, in addition to any
> resource-specific tags that might be defined. This enables
> [searching for resources based on tags](https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/tag-support)
> and can be helpful if manual cleanup is necessary.
> To see these applied tags, run `terraform output common_tags`.

# Security disclaimer

By default, the allowed inbound and SSH CIDR block is `0.0.0.0/0` aka The Entire Internet.

It is certainly advised to scope the allowed SSH CIDR block down to a single IP or known subset.

As this example takes a stock Ubuntu virtual machine image and then proceeds to download Fermyon and Hashistack binaries,
the default inbound CIDR block is likely necessary for first startup. After confirmation that
Fermyon is up and running - and as long as subsequent apps/workloads won't need access to
the broader internet - this value may be updated on a subsequent `terraform apply` if desired, e.g.
`terraform apply -var=allowed_inbound_cidr_blocks=["75.75.75.75/32"]`.

# How to Deploy

First, navigate to the `terraform` directory and initialize Terraform:

```console
cd terraform
terraform init
```

Deploy with all defaults (http-based URLs):

```console
terraform apply
```

Deploy with all defaults and use Let's Encrypt to provision certs for TLS/https:

```console
terraform apply -var='enable_letsencrypt=true'
```

Deploy with a custom virtual machine name, perhaps so multiple examples can co-exist in the same region:

```console
terraform apply -var='vm_name=fermyonrocks'
```

Deploy with a custom domain name:

```console
terraform apply -var='dns_host=example.com'
```

Quick disclaimer when Let's Encrypt is enabled: if the DNS record does not propagate in time,
Let's Encrypt may incur a rate limit on your domain. Create the A record for \*.example.com as soon as you can,
making sure it points to the Azure IP's public address.
See https://letsencrypt.org/docs/staging-environment/#rate-limits for more details.

## Environment setup

When Terraform finishes provisioning, it will supply URL and username/password
values for Hippo and Bindle, which will be needed to deploy your first
application.

Set your environment up in one go using the `environment` output:

```console
$(terraform output -raw environment)
```

This will export values into your shell for the following environment
variables:

- `DNS_DOMAIN`
- `HIPPO_USERNAME`
- `HIPPO_PASSWORD`
- `HIPPO_URL`
- `BINDLE_URL`

Now you're ready to start building and deploying applications on Fermyon!
Follow the [Deploying to Fermyon](../deploy.md) guide for the next steps.

## Cleaning up

When the provisioned resources in this example are no longer needed, they can be destroyed via:

```console
terraform destroy
```

# Troubleshooting/Debugging

## SSH into Azure VM

```console
terraform output -raw tls_private_key > /tmp/tls_private_key.pem
chmod 0600 /tmp/tls_private_key.pem
ssh -i /tmp/tls_private_key.pem ubuntu@$(terraform output -raw public_ip_address)
```

Once on the virtual machine, output from user-data.sh, which is the script
that runs at startup time, can be checked like so:

```console
ubuntu@ip-10-0-0-12:~$ tail -n15 /var/log/cloud-init-output.log

Logs are stored in ./log

Export these into your shell

    export CONSUL_HTTP_ADDR=http://10.0.0.12:8500
    export NOMAD_ADDR=http://127.0.0.1:4646
    export VAULT_ADDR=http://localhost:8200
    export VAULT_TOKEN=devroot
    export VAULT_UNSEAL=lZzl7uhktA8uBYgqijPsar5IPD7kH4xa6WR2qvNbnwo=
    export BINDLE_URL=https://bindle.52.44.146.193.sslip.io/v1
    export HIPPO_URL=https://hippo.52.44.146.193.sslip.io

Ctrl+C to exit.
```

The Hashistack CLIs can be used to dig deeper.

### Check Consul

```console
ubuntu@ip-10-0-0-12:~$ consul members status
Node          Address         Status  Type    Build   Protocol  DC   Partition  Segment
ip-10-0-0-12  10.0.0.12:8301  alive   server  1.12.0  2         dc1  default    <all>
```

### Check Nomad

```console
ubuntu@ip-10-0-0-12:~$ nomad status
ID       Type     Priority  Status   Submit Date
bindle   service  50        running  2022-05-18T23:42:51Z
hippo    service  50        running  2022-05-18T23:43:09Z
traefik  service  50        running  2022-05-18T23:42:31Z
```

### Check Vault

```console
ubuntu@ip-10-0-0-12:~$ vault status -address http://127.0.0.1:8200
Key             Value
---             -----
Seal Type       shamir
Initialized     true
Sealed          false
Total Shares    1
Threshold       1
Version         1.10.3
Storage Type    file
Cluster Name    vault-cluster-75996a7a
Cluster ID      76c0a164-4e08-d1f4-b170-871787674bbb
HA Enabled      false
```

### Check Traefik

```console
ubuntu@ip-10-0-0-12:~$ nomad logs -job traefik
time="2022-05-18T23:42:32Z" level=info msg="Configuration loaded from file: /home/ubuntu/data/nomad/alloc/1737c563-b9d8-cd1e-65dc-a1f7fb9cdd48/traefik/local/traefik.toml"
time="2022-05-18T23:42:32Z" level=info msg="Traefik version 2.6.6 built on 2022-05-03T16:58:48Z"
...
```

## Advanced: Accessing Nomad and/or Consul from outside of the Azure VM

You may wish to access the Nomad and/or Consul APIs from outside of the Azure VM.

### Access via SSH tunnel

The safest approach is to access the services via SSH tunnels.

#### Access Nomad and Consul

Nomad is configured to run on port 4646 and Consul on 8500. This following command sets
up the local SSH tunnel and will run until stopped:

```console
ssh -i /tmp/tls_private_key.pem \
  -L 4646:127.0.0.1:4646 \
  -L 8500:127.0.0.1:8500 \
  -N ubuntu@$(terraform output -raw public_ip_address)
```

You should now be able to interact with these services, for example by navigating in your
browser to the Nomad dashboard at 127.0.0.1:4646.

(Additional ports may be added, for instance 8200 for Vault, 8081 for Traefik, etc.)

### Access via Azure VM ports

Alternatively, the ports can be opened up at the Azure Network Security Group level. Note, however, that these
currently run on unsecured http ports, therefore it is highly encouraged to minimally
update the terraform deploy to restrict inbound IP addresses (`var.allowed_inbound_cidr_blocks`).
Otherwise, The Entire Internet will have access to the Nomad and Consul instances.

### Open up the Nomad http port

This will allow traffic to the `4646` port at the public Azure IP address:

```console
terraform apply -var='allow_inbound_http_nomad=true'
```

### Open up the Consul http port

This will allow traffic to the `8500` port at the public Azure IP address:

```console
terraform apply -var='allow_inbound_http_consul=true'
```
