# Nomad on AWS - Quick Start

# Prereqs

- AWS account
  - Secrets/values via env vars:
    - `AWS_ACCESS_KEY_ID=xxx`
    - `AWS_SECRET_ACCESS_KEY=xxx`
    - `AWS_DEFAULT_REGION=us-east-1`
  - Or local `aws` CLI configuration (see `~/.aws/config` and `~/.aws/credentials`)

- `terraform` cli

# Resources deployed

TODO

# Security disclaimer

TODO

At least a disclaimer around allowed ssh/inbound cidr blocks (should really limit to your own IP, etc),
perhaps we should update the defaults in variables.tf to be empty (no access) as well.

# How to Deploy

Deploy with Let's Encrypt staging URL for testing:

```console
terraform apply
```

Deploy with Let's Encrypt prod URL for happy TLS:

```console
terraform apply -var='letsencrypt_env=prod'
```

Conversely, when all wrapped up, resources can be destroyed via:

```console
terraform destroy
```

# SSH into EC2 instance

```console
terraform output -raw ec2_ssh_private_key > ec2_ssh_private_key.pem
ssh -i ec2_ssh_private_key.pem ubuntu@$(terraform output -raw eip_public_ip_address)
```

# Troubleshooting/Debugging

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

```console
ubuntu@ip-10-0-0-12:~$ nomad logs -tail -n 10 -job traefik
ad
time="2022-05-18T23:50:47Z" level=debug msg="Filtering disabled item" providerName=consulcatalog serviceName=nomad-client
time="2022-05-18T23:50:47Z" level=debug msg="Filtering disabled item" serviceName=traefik providerName=consulcatalog
time="2022-05-18T23:50:47Z" level=debug msg="Configuration received from provider consulcatalog: {\"http\":{\"routers\":{\"bindle\":{\"entryPoints\":[\"websecure\"],\"service\":\"bindle\",\"rule\":\"Host(`bindle.52.44.146.193.sslip.io`)\",\"tls\":{\"certResolver\":\"letsencrypt-tls-prod\",\"domains\":[{\"main\":\"bindle.52.44.146.193.sslip.io\"}]}},\"hippo\":{\"entryPoints\":[\"websecure\"],\"service\":\"hippo\",\"rule\":\"Host(`hippo.52.44.146.193.sslip.io`)\",\"tls\":{\"certResolver\":\"letsencrypt-tls-prod\",\"domains\":[{\"main\":\"hippo.52.44.146.193.sslip.io\"}]}}},\"services\":{\"bindle\":{\"loadBalancer\":{\"servers\":[{\"url\":\"http://10.0.0.12:29096\"}],\"passHostHeader\":true}},\"hippo\":{\"loadBalancer\":{\"servers\":[{\"url\":\"http://10.0.0.12:5000\"}],\"passHostHeader\":true}}}},\"tcp\":{},\"udp\":{}}" providerName=consulcatalog
time="2022-05-18T23:50:47Z" level=debug msg="Skipping same configuration" providerName=consulcatalog
```