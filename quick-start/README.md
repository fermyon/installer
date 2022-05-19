# Nomad on AWS - Quick Start

# Prerequisites

- An AWS account
  - The credentials needed by Terraform can be provided via env vars:
    ```console
      export AWS_ACCESS_KEY_ID=xxx
      export AWS_SECRET_ACCESS_KEY=xxx
      export AWS_DEFAULT_REGION=us-east-1
    ```
  - Or via local [aws CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
    configuration (see `~/.aws/config` and `~/.aws/credentials`)

- The [terraform CLI](https://learn.hashicorp.com/tutorials/terraform/install-cli#install-terraform)

# Resources deployed

This example creates the following resources in the provided AWS account:
  - 1 EC2 instance (default size: `t2.micro`)
  - 1 Elastic IP address (associated with instance)
    - This is useful as it won't change with instance reboots and is a known
      value for constructing Hippo and Bindle URLs
  - 1 VPC to host the EC2 instance, using a private IP address range
    - 1 subnet
    - 1 network interface
    - 1 custom security group with
      - Inbound connections allowed for ports 22, 80 and 443
        - see `var.allowed_inbound_cidr_blocks` for allowed origin IP addresses
      - All outbound connections allowed
    - 1 internet gateway and route table for connection to the broader internet
  - 1 SSH keypair
    - see `var.allowed_ssh_cidr_blocks` for allowed origin IP addresses

# Security disclaimer

By default, the allowed inbound and SSH CIDR block is `0.0.0.0/0` aka The Entire Internet.

It is certainly advised to scope the allowed SSH CIDR block down to a single IP or known subset.

As this example takes a stock Ubuntu AMI and then proceeds to download Fermyon and Hashistack binaries,
the default inbound CIDR block is likely necessary for first startup. After confirmation that the
Fermyon Platform is up and running - and as long as subsequent apps/workloads won't need access to
the broader internet - this value may be updated on a subsequent `terraform apply` if desired, e.g.
`terraform apply -var=allowed_inbound_cidr_blocks=["75.75.75.75/32"]`.

# How to Deploy

Deploy with all defaults and using the Let's Encrypt staging URL for testing:

```console
terraform apply
```

Deploy with all defaults and using the Let's Encrypt prod URL for happy TLS:

```console
terraform apply -var='letsencrypt_env=prod'
```

Deploy with a custom instance name, perhaps so multiple examples can co-exist in the same region:

```console
terraform apply -var='instance_name=fermyonrocks'
```

Conversely, when all wrapped up, resources can be destroyed via:

```console
terraform destroy
```

# Interacting with the Fermyon Platform

Once this example has been deployed, you're ready to start building and deploying applications
on the Fermyon Platform.

Follow the [Spin documentation](https://spin.fermyon.dev/) or
[Hippo documentation](https://docs.hippofactory.dev/) to get started.

# Troubleshooting/Debugging

## SSH into EC2 instance

```console
terraform output -raw ec2_ssh_private_key > /tmp/ec2_ssh_private_key.pem
chmod 0600 /tmp/ec2_ssh_private_key.pem
ssh -i /tmp/ec2_ssh_private_key.pem ubuntu@$(terraform output -raw eip_public_ip_address)
```

Once on the instance, output from user-data.sh can be checked like so:

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
ubuntu@ip-10-0-0-12:~$ vault status
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
