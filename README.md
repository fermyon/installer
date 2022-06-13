# Fermyon Installer

Fermyon is a platform to host [Spin](https://spin.fermyon.dev) applications
and other compatible WebAssembly workloads.

The resources in this repository are intended to provide users with different
ways to deploy ("install") Fermyon in their preferred environment.

## The Fermyon Stack

Fermyon runs on [Nomad](https://nomadproject.io), so deployment scenarios
will first configure and install this software, in tandem with
[Consul](https://consul.io) and [Vault](https://vaultproject.io).

Afterwards, the components comprising Fermyon are deployed in the
form of Nomad jobs, including a [Bindle](https://github.com/deislabs/bindle)
server, [Traefik](https://docs.traefik.io) as the reverse proxy/load balancer
and [Hippo](https://github.com/deislabs/hippo), the web UI for managing
Spin-based applications.

## Quick-starts

### AWS

The [AWS Quick-start](./aws/quick-start) utilizes
[Terraform](https://terraform.io) to deploy a lightweight, working example
of Fermyon on AWS. This is a great route to go for quickly testing out the
platform, as it only creates the minimal array of AWS resources needed to run
the services.

Users will be able to interact with publicly-accessible Bindle and Hippo
services within 5 minutes of starting the deployment and can then start
deploying their applications.

To get started, head over to the [README.md](./aws/quick-start/README.md).