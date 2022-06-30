# Fermyon Installer

Fermyon is a platform to host [Spin](https://spin.fermyon.dev) applications
and other compatible WebAssembly workloads.

The resources in this repository are intended to provide users with different
ways to deploy ("install") Fermyon in their preferred environment.

## The Fermyon Stack

Fermyon runs on [Nomad](https://nomadproject.io), so deployment scenarios
will first configure and install this software, in tandem with
[Consul](https://consul.io).

Afterwards, the components comprising Fermyon are deployed in the
form of Nomad jobs, including a [Bindle](https://github.com/deislabs/bindle)
server, [Traefik](https://docs.traefik.io) as the reverse proxy/load balancer
and [Hippo](https://github.com/deislabs/hippo), the web UI for managing
Spin-based applications.

# Installers

## Local
---

Looking to install Fermyon on your local machine? Follow the
[local](./local/README.md) guide to get started.

Once the
[prerequisites](./local/README.md#prerequisites) have been installed, this
is the quickest and easiest method to launch Fermyon and begin deploying
apps.

## AWS
---

The [AWS Quick-start](./aws/README.md) is a great option to go if you'd like
to run Fermyon in a separate environment.

This installer utilizes [Terraform](https://terraform.io) to deploy a
lightweight, working example of Fermyon on AWS, using only a minimal array of
resources needed to run the services.

You'll be able to interact with publicly-accessible Bindle and Hippo services
within 5 minutes of invoking `terraform apply`. From there, you can start
deploying your applications.

# Deploying to Fermyon

After installing Fermyon in your preferred environment, you are ready to deploy
your first application.

Follow the [deploy guide](deploy.md) to get started.