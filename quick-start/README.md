# Nomad on AWS - Quick Start

This is a Quick Start example to deploy Nomad and Fermyon Platform on AWS
using Terraform.

As such, this is intended solely for evaluation and/or demo scenarios, i.e.
*not* for production.

All Hashistack (Nomad, Consul, Vault), Traefik and Fermyon Platform processes run
without any redundancy on a single EC2 instance. There is no data backup for any
service.

That being said, it should give users a quick look and feel for deploying apps
onto the Fermyon Platform. Apps will by default be provided with TLS certs via
Traefik's Let's Encrypt integration and will be accessible to the broader internet
(depending on configuration details mentioned below).

# Prerequisites

- An AWS account
  - The credentials needed by Terraform can be provided via env vars:
    ```console
      export AWS_ACCESS_KEY_ID=xxx
      export AWS_SECRET_ACCESS_KEY=xxx
      export AWS_REGION=us-east-1
    ```
  - Or via local [aws CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
    configuration (see `~/.aws/config` and `~/.aws/credentials`)

  - _Note: If your AWS user is in a group that enforces MFA for all requests,
    see the following guide on [generating a session token](#generating-a-session-token-in-aws)
    prior to running this automation._

- The [terraform CLI](https://learn.hashicorp.com/tutorials/terraform/install-cli#install-terraform)

# Resources deployed

This example creates the following resources in the provided AWS account:
  - 1 EC2 instance (default size: `t2.small`)
  - 1 Elastic IP address (associated with instance)
    - This is useful as it won't change with instance reboots and is a known
      value for constructing Hippo and Bindle URLs
  - 1 custom security group using the default VPC with:
    - Inbound connections allowed for ports 22, 80 and 443
      - see `var.allowed_inbound_cidr_blocks` for allowed origin IP addresses
    - All outbound connections allowed
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

First, navigate to the `terraform` directory and initialize Terraform:

```console
cd terraform
terraform init
```

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

Deploy with a custom domain name:

```console
terraform apply -var='dns_host=example.com'
```

Quick disclaimer with `letsencrypt_env=prod`: if the DNS record does not propagate in time, Let's Encrypt may incur a rate limit on your domain. Create the A record for *.example.com as soon as you can, making sure it points to the Elastic IP's public address. See https://letsencrypt.org/docs/staging-environment/#rate-limits for more details.

When all wrapped up, resources can be destroyed via:

```console
terraform destroy
```

# Interacting with the Fermyon Platform

Once this example has been deployed, you're ready to start building and deploying applications
on the Fermyon Platform.

For in-depth guides, follow the [Spin documentation](https://spin.fermyon.dev/) or
[Hippo documentation](https://docs.hippofactory.dev/) to get started.

## Example flow

Here's an example flow once `terraform apply` completes.

First, export pertinent environment variables using the `environment` output:

```console
$(terraform output -raw environment)
```

This will export the following environment variables, for use by the CLIs and example
commands below:

  - `ELASTIC_IP_ADDRESS`
  - `DNS_DOMAIN`
  - `HIPPO_USERNAME`
  - `HIPPO_PASSWORD`
  - `HIPPO_URL`
  - `BINDLE_URL`

Next, `cd` to your Spin app directory, login to Hippo and deploy your app. (Note: the `hippo login`
and `spin deploy` commands may require `-k` if running with the `letsencrypt_env` variable
set to `staging`; which is the current default.)

Here we've entered the [examples/http-rust](https://github.com/fermyon/spin/tree/main/examples/http-rust)
directory in the [fermyon/spin](https://github.com/fermyon/spin) GitHub repository:

```console
$ cd ~/code/github.com/fermyon/spin/examples/http-rust

$ hippo login
Logged in as admin

$ spin build
<output omitted>

$ spin deploy
Successfully deployed application!
```

We can then hit our app's served route (`/hello`) via its URL. First, navigate to the Hippo dashboard
(`$HIPPO_URL`), log in with the `$HIPPO_USERNAME` and `$HIPPO_PASSWORD` values and then find the app's
URL on the app page.

For example, when using the default DNS host of `sslip.io`, hitting the endpoint would look something like
the following:

```console
$ curl https://spin-hello-world.spin-hello-world.hippo.52.44.146.193.sslip.io/hello
Hello, Fermyon!
```

A few notes:

- It can take a few moments for Traefik to obtain the Let's Encrypt cert for the app domain
- The current structure for an app's URL on Hippo is `https://<channel name>.<app name>.hippo.<domain>`.
  When deploying with `spin deploy`, the app name is used for the hippo channel name as well.

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

## Advanced: Accessing Nomad and/or Consul from outside of the EC2 instance

You may wish to access the Nomad and/or Consul APIs from outside of the EC2 instance.

### Access via SSH tunnel

The safest approach is to access the services via SSH tunnels.

#### Access Nomad and Consul

Nomad is configured to run on port 4646 and Consul on 8500.  Here we include both for the SSH tunnel:

```console
ssh -i /tmp/ec2_ssh_private_key.pem \
  -L 4646:127.0.0.1:4646 \
  -L 8500:127.0.0.1:8500 \
  -N ubuntu@$(terraform output -raw eip_public_ip_address)
```

(Additional ports may be added, for instance 8200 for Vault, 8081 for Traefik, etc.)

Alternatively, the ports can be opened up at the EC2 firewall level. Note, however, that these
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

## Generating a session token in AWS

If your AWS user is associated with an MFA-only policy, you'll most likely need
to generate a temporary set of credentials prior to running this automation.

Here's an example that invokes the `aws sts get-session-token` command while
supplying the ARN of the MFA device associated with the user account, as well
as a current token from this device. (Note: `aws iam list-mfa-devices` can be
invoked to find the corresponding device ARN.)

The command will return JSON which can be saved to a local file. A tool like
[jq](https://stedolan.github.io/jq/) can then be used to parse the JSON and load
values into their respective environment variables.

By default, the credentials are valid for 12 hours. See the
[AWS documentation](https://aws.amazon.com/premiumsupport/knowledge-center/authenticate-mfa-cli/)
for further details.

```console
$ aws sts get-session-token \
  --serial-number <arn of the mfa device> \
  --token-code <code from token> > session-token.json

$ cat session-token.json | jq
{
  "Credentials": {
    "AccessKeyId": "xxx",
    "SecretAccessKey": "xxx",
    "SessionToken": "xxx",
    "Expiration": "2022-05-26T05:52:56+00:00"
  }
}

$ export AWS_ACCESS_KEY_ID="$(cat session-token.json | jq -j '.Credentials.AccessKeyId')"
$ export AWS_SECRET_ACCESS_KEY="$(cat session-token.json | jq -j '.Credentials.SecretAccessKey')"
$ export AWS_SESSION_TOKEN="$(cat session-token.json | jq -j '.Credentials.SessionToken')"
```
