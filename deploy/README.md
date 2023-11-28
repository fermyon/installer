# Deployments

The [Fermyon Platform](https://www.fermyon.dev) website is deployed via the [deploy.yaml](../.github/workflows/deploy.yml) GitHub workflow.

## Auto Deploys

The production version of the website is deployed whenever commits are pushed to the `main` branch.

## Manual Deploys

Deployments may also be [triggered manually](https://github.com/fermyon/installer/actions/workflows/deploy.yml), providing a choice of `ref` and `sha`.

## Nomad jobs

We currently deploy the website via its Nomad job directly. (In the future, we envision running the website as a Fermyon Cloud app.)

The [platform-docs](./platform-docs.nomad) Nomad job contains configuration for the running website, including the OCI reference to run from.
