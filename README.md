# Nomad and the Fermyon Platform on AWS

The resources in this repository are intended to show working examples of
deploying Nomad and the Fermyon Platform using Amazon Web Services (AWS).

The Fermyon Platform runs on [Nomad](https://nomadproject.io), so examples
will first configure and deploy this software, usually in tandem with
[Consul](https://consul.io) and [Vault](https://vaultproject.io). These three
together are casually referred to as the Hashistack.

Afterwards, the components comprising the Fermyon Platform are deployed in the
form of Nomad jobs, including a [Bindle](https://github.com/deislabs/bindle)
server, [Traefik](https://docs.traefik.io) as the reverse proxy/load balancer
and [Hippo](https://github.com/deislabs/hippo), the web UI for managing
[Spin](https://spin.fermyon.dev)-based Fermyon Platform applications.

## Quick-start

The [Quick-start](./quick-start) directory contains
[Terraform](https://terraform.io)-based automation for deploying a lightweight,
working example onto AWS. This is a great route to go for quickly testing out
the Fermyon Platform, as it only creates the minimal array of AWS resources
needed to run the services.

Users will be able to interact with publicly-accessible Bindle and Hippo
services via https endpoints within 5 minutes of starting the deployment.

See further details via the [Quick-start README.md](./quick-start/README.md)
and try it out!