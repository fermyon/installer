# DigitalOcean README

This guide illustrates how to install Fermyon on DigitalOcean using Terraform.

As such, this is intended solely for evaluation and/or demo scenarios, i.e.
*not* for production.

All Hashistack (Nomad, Consul, Vault), Traefik and Fermyon platform processes run
without any redundancy on a single Droplet instance. There is no data backup for any
service.

That being said, it should give users a quick look and feel for deploying apps
using Fermyon. By default, all apps will be accessible to the broader internet
(see the configuration details mentioned below). Additionally, when Let's Encrypt
is enabled, apps will be provided with https URLs and TLS certs.

# Prerequisites

- A DigitalOcean account with a [personal access token](https://docs.digitalocean.com/reference/api/create-personal-access-token/).
- The [terraform CLI](https://learn.hashicorp.com/tutorials/terraform/install-cli#install-terraform)

# Resources deployed

This example creates the following resources in the provided DigitalOcean project:
  - 1 Droplet instance type
    - Name: `${var.droplet_name}` (default: `fermyon`)
    - Type: `${var.droplet_size}` (default: `s-2vcpu-2gb`)
  - 1 Reserved IP address (associated with instance)
    - This is useful as it won't change with instance reboots and is a known
      value for constructing Hippo and Bindle URLs
  - 1 custom VPC
    - Name: `${var.vpc_name}` (default: `fermyon-vpc`)
    - Note: if this is the first VPC in a region, it will be default VPC, so this VPC can't delete by `terraform destroy`.
  - 6 custom firewalls
    - Inbound connections allowed for ports 22, 80 and 443
      - see `var.allowed_inbound_cidr_blocks` for allowed origin IP addresses
    - All outbound connections allowed
  - 1 SSH keypair
    - see `var.allowed_ssh_cidr_blocks` for allowed origin IP addresses

# Security disclaimer

By default, the allowed inbound and SSH CIDR block is `0.0.0.0/0` aka The Entire Internet.

It is certainly advised to scope the allowed SSH CIDR block down to a single IP or known subset.

As this example takes a stock Ubuntu 20.04 LTS and then proceeds to download Fermyon and Hashistack binaries,
the default inbound CIDR block is likely necessary for first startup. After confirmation that
Fermyon is up and running - and as long as subsequent apps/workloads/ssh won't need access to
the broader internet - this value may be updated on a subsequent `terraform apply` if desired, e.g.:

```console
terraform apply -var='allowed_inbound_cidr_blocks=["75.75.75.75/32"]' -var='allowed_ssh_cidr_blocks=["75.75.75.75/32"]'
```

# How to Deploy

First, [create a personal access token](https://docs.digitalocean.com/reference/api/create-personal-access-token/) and set the `DIGITALOCEAN_TOKEN` environment variable.

```console
export DIGITALOCEAN_TOKEN="dop_v1_xxx"
```

Second, navigate to the `terraform` directory and initialize Terraform:

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

Deploy with a custom instance name, perhaps so multiple examples can co-exist in the same region:

```console
terraform apply -var='droplet_name=fermyonrocks'
```

Deploy with a custom domain name:

```console
terraform apply -var='dns_host=example.com'
```

Quick disclaimer when Let's Encrypt is enabled: if the DNS record does not propagate in time,
Let's Encrypt may incur a rate limit on your domain. Create the A record for *.example.com as soon as you can,
making sure it points to the provisioned public IP address.
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

## SSH into the Droplet instance

```console
terraform output -raw droplet_ssh_private_key > /tmp/droplet_ssh_private_key.pem
chmod 0600 /tmp/droplet_ssh_private_key.pem
ssh -i /tmp/droplet_ssh_private_key.pem root@$(terraform output -raw public_ip_address)
```

Once on the instance, output from user-data.sh, which is the script
that runs at startup time, can be checked like so:

```console
root@fermyon:~$ tail -n15 /var/log/cloud-init-output.log

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
root@fermyon:~$ consul members status
Node     Address              Status  Type    Build   Protocol  DC   Partition  Segment
fermyon  161.35.106.110:8301  alive   server  1.12.1  2         dc1  default    <all>
```

### Check Nomad

```console
root@fermyon:~$ nomad status
ID       Type     Priority  Status   Submit Date
bindle   service  50        running  2022-07-12T16:30:40Z
hippo    service  50        running  2022-07-12T16:31:02Z
traefik  service  50        running  2022-07-12T16:30:22Z
```

### Check Vault

```console
root@fermyon:~$ vault status
Key             Value
---             -----
Seal Type       shamir
Initialized     true
Sealed          false
Total Shares    1
Threshold       1
Version         1.10.3
Storage Type    file
Cluster Name    vault-cluster-7929ac40
Cluster ID      6e351bf4-bdcb-ed75-5ab7-f62b15f7e236
HA Enabled      false
```

### Check Traefik

```console
root@fermyon:~$ nomad logs -job traefik
time="2022-05-18T23:42:32Z" level=info msg="Configuration loaded from file: /home/ubuntu/data/nomad/alloc/1737c563-b9d8-cd1e-65dc-a1f7fb9cdd48/traefik/local/traefik.toml"
time="2022-05-18T23:42:32Z" level=info msg="Traefik version 2.6.6 built on 2022-05-03T16:58:48Z"
...
```

## Advanced: Accessing Nomad and/or Consul from outside of the Droplet instance

You may wish to access the Nomad and/or Consul APIs from outside of the Droplet instance.

### Access via SSH tunnel

The safest approach is to access the services via SSH tunnels.

#### Access Nomad and Consul

Nomad is configured to run on port 4646 and Consul on 8500. This following command sets
up the local SSH tunnel and will run until stopped:

```console
ssh -i /tmp/droplet_ssh_private_key.pem \
  -L 4646:127.0.0.1:4646 \
  -L 8500:127.0.0.1:8500 \
  -N root@$(terraform output -raw public_ip_address)
```

You should now be able to interact with these services, for example by navigating in your
browser to the Nomad dashboard at 127.0.0.1:4646.

(Additional ports may be added, for instance 8200 for Vault, 8081 for Traefik, etc.)

### Access via Droplet instance ports

Alternatively, the ports can be opened up at the Droplet firewall level. Note, however, that these
currently run on unsecured http ports, therefore it is highly encouraged to minimally
update the terraform deploy to restrict inbound IP addresses (`var.allowed_inbound_cidr_blocks`).
Otherwise, The Entire Internet will have access to the Nomad and Consul instances.

### Open up the Nomad http port

This will allow traffic to the `4646` port at the public Elastic IP address:

```console
terraform apply -var='allow_inbound_http_nomad=true'
```

### Open up the Consul http port

This will allow traffic to the `8500` port at the public Elastic IP address:

```console
terraform apply -var='allow_inbound_http_consul=true'
```
