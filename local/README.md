# Local Quick Start

This is a Quick Start example to run Fermyon locally.

As such, this is intended solely for evaluation and/or demo scenarios, i.e.
*not* for production.

The environment is ephemeral and will not persist any data.

# Prerequisites

- [Nomad](https://www.nomadproject.io/docs/install)
- [Consul](https://www.consul.io/docs/install)
- [spin](https://github.com/fermyon/spin)

# How to Deploy

```console
./start.sh
```

# Deploying to Fermyon
## Using 'AdministratorOnly' registration mode (default)
When using the `AdministratorOnly` registration mode, only a single
administration account will be able to schedule workloads.  When running your
Nomad job, you will have to pass in a value for the following variables:
- `admin_username`
- `admin_password`

Using the provided `start.sh` script, you can set the environment variables
`HIPPO_ADMIN_USERNAME` and `HIPPO_ADMIN_PASSWORD` to override the default 
values (`admin`, and `password`, respectively); i.e.:
```
HIPPO_ADMIN_USERNAME=myclevername HIPPO_ADMIN_PASSWORD=<strong random password> ./start.sh
```

## Using 'Open' registration mode
Once the script finishes deploying Fermyon services it will print a list of
export statements. Copy these to your clipboard, leave the script running and
open a new terminal window.

Next, navigate your browser to Hippo (e.g. `open $HIPPO_URL`) and register a
new account. The username and password values will be needed when deploying
your Spin application, so export these into your terminal as well:

```console
export HIPPO_USERNAME=<username>
export HIPPO_PASSWORD=<password>
```

Now you are ready to deploy your first application on Fermyon. Follow the
[guide to get started](../deploy.md).
