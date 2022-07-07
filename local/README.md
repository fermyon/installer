# Local Quick Start

This is a Quick Start example to run Fermyon locally.

As such, this is intended solely for evaluation and/or demo scenarios, i.e.
*not* for production.

The environment is ephemeral and will not persist any data.

# Prerequisites

- [Nomad](https://www.nomadproject.io/docs/install) v1.3 or later
- [Spin](https://github.com/fermyon/spin)

# How to Deploy

```console
./start.sh
```

# Deploying to Fermyon

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
