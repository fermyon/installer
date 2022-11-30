# AWS Multi-node

Welcome to the AWS Multi-node installer. This option deploys a default of 3
instances with data persisted via EBS volumes.

Currently, the infrastructure selects a single node with an elastic ip to receive requests,
so it does have a single point of failure. We hope to introduce
[load balancing](https://github.com/fermyon/installer/issues/115) in the near future.

# Prerequisites

See the main [AWS README.md](../../README.md#prerequisites) for prerequisites.

# Resources deployed

This example creates the following resources in the provided AWS account:
  - 3 EC2 instances (default size: `t2.medium`)
    - Name: `${var.resource_name_prefix}-server`
  - 1 Elastic IP address (associated with the first instance)
    - Name: `${var.resource_name_prefix}-eip`
    - This is useful as it won't change with instance reboots and is a known
      value for constructing Hippo and Bindle URLs
  - 1 custom security group using the default VPC
    - Name: `${var.resource_name_prefix}-server-sg`
    - Inbound connections allowed for ports 22, 80, 443 and optionally: 8081 (traefik), 4646 (nomad), and 8500 (consul)
      - see `var.allowed_inbound_cidr_blocks` for allowed origin IP addresses
    - All outbound connections allowed
  - 1 SSH keypair
    - Name: `${var.resource_name_prefix}_ssh_key_pair`
    - see `var.allowed_ssh_cidr_blocks` for allowed origin IP addresses
  - 2 EBS volumes
    - Postgres: the database for hippo
      - Name: `${var.resource_name_prefix}-postgres-volume`
      - Size: 20 GB
        - see `var.postgres_disk_size` to change the disk size
    - Bindle
      - Name: `${var.resource_name_prefix}-bindle-volume`
      - Size: 20 GB
        - see `var.bindle_disk_size` to change the disk size


> All resources are tagged with a common set of tags, in addition to any
resource-specific tags that might be defined. This enables
[searching for resources based on tags](https://docs.aws.amazon.com/ARG/latest/userguide/tag-editor.html)
and can be helpful if manual cleanup is necessary.
To see these applied tags, run `terraform output common_tags`.

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

Deploy with a custom instance name, perhaps so multiple examples can co-exist in the same region:

```console
terraform apply -var='resource_name_prefix=fermyonrocks'
```

Deploy with a custom domain name:

```console
terraform apply -var='dns_host=example.com'
```

Quick disclaimer when Let's Encrypt is enabled: if the DNS record does not propagate in time,
Let's Encrypt may incur a rate limit on your domain. Create the A record for *.example.com as soon as you can,
making sure it points to the Elastic IP's public address.
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

See the main [AWS README.md](../../README.md#troubleshootingdebugging) for
approaches around troubleshooting as well as advanced configurations.
