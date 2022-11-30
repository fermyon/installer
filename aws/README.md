# AWS README

This guide illustrates how to install Fermyon on AWS using Terraform.

As such, this is intended solely for evaluation and/or demo scenarios, i.e.
*not* for production.

That being said, it should give users a quick look and feel for deploying apps
using Fermyon. By default, all apps will be accessible to the broader internet
(see the configuration details mentioned below). Additionally, when Let's Encrypt
is enabled, apps will be provided with https URLs and TLS certs courtesy LE.

# Prerequisites

- An AWS account
  - The credentials needed by Terraform can be provided via env vars:
    ```console
      export AWS_ACCESS_KEY_ID=xxx
      export AWS_SECRET_ACCESS_KEY=xxx
      export AWS_REGION=us-east-1
    ```
  - Or via local [AWS CLI configuration](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html)

  - _Note: If your AWS user is in a group that enforces MFA for all requests,
    see the following guide on [generating a session token](#generating-a-session-token-in-aws)
    prior to running this automation._

- The [terraform CLI](https://learn.hashicorp.com/tutorials/terraform/install-cli#install-terraform)

# Configurations

We currently offer the following configurations for running the Fermyon
Platform on AWS:

- [AWS Single-node](./terraform/single-node/README.md)

  This option launches one EC2 instance to host all of the platform services,
  plus the minimal amount of auxiliary resources. It is a great option for
  test-driving the platform on AWS as it is quick to launch and quick to tear
  down. There is no data persistence.

- [AWS Multi-node](./terraform/multiple-nodes/README.md)

  This option launches 3 EC2 instances (the number can be scaled as needed) in
  tandem with EBS volumes for platform data. This increases the cloud resource
  footprint and takes a little more time to launch, but brings greater
  robustness and customizability for running real-world workloads.

# Security disclaimer

By default for both scenarios, the allowed inbound and SSH CIDR block is
`0.0.0.0/0` aka The Entire Internet.

It is certainly advised to scope the allowed SSH CIDR block down to a single IP or known subset.

As these examples take a stock Ubuntu AMI and then downloads Fermyon and Hashistack binaries,
the default inbound CIDR block is likely necessary for first startup. After confirmation that
Fermyon is up and running - and as long as subsequent apps/workloads won't need access to
the broader internet - this value may be updated on a subsequent `terraform apply` if desired, e.g.
`terraform apply -var=allowed_inbound_cidr_blocks=["75.75.75.75/32"]`.

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

Nomad is configured to run on port 4646 and Consul on 8500. This following command sets
up the local SSH tunnel and will run until stopped:

```console
ssh -i /tmp/ec2_ssh_private_key.pem \
  -L 4646:127.0.0.1:4646 \
  -L 8500:127.0.0.1:8500 \
  -N ubuntu@$(terraform output -raw eip_public_ip_address)
```

You should now be able to interact with these services, for example by navigating in your
browser to the Nomad dashboard at 127.0.0.1:4646.

(Additional ports may be added, for instance 8200 for Vault, 8081 for Traefik, etc.)

### Access via EC2 ports

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

_Note: AWS currently [does not support FIDO security keys with its CLI tool](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_mfa_fido_supported_configurations.html#id_credentials_mfa_fido_cliapi)._

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
