title = "The frictionless WebAssembly platform for writing microservices and web apps"
template = "main"
date = "2022-06-08T00:22:56Z"
[extra]
url = "https://github.com/fermyon/installer/blob/main/docs/content/index.md"
---

With Fermyon, you can deploy your Spin applications onto a server in moments. For developers, it offers a rapid self-service cloud application platform (or Platform-as-a-Service). For DevOps, Fermyon provides orchestration, networking, service discovery, and a web UI for Spin applications.


### For Developers

For the developer, Fermyon works like a cloud application platform or PaaS (think CloudFoundry or Heroku, but for Spin apps). With just a few commands, a developer can go from a blinking cursor to a deployed application:

* Use `spin new` to create a new application
* Then `spin build` to locally build it
* Finally, use `spin deploy` to deploy it to Fermyon

The Fermyon dashboard, a web app, makes it easy to configure your app, choose a channel (dev, stage, prod), and check the status and logs.

>> Fermyon offers all of the perks of a deployment platform, including a web UI. But if you are just doing local development, you can use `spin up` and `spin build --up` to run your app locally.

The [Spin quickstart](https://spin.fermyon.dev) will get you going with Spin. Read on if you want to install Fermyon on a server or in the cloud.

### For DevOps

From the DevOps perspective, Fermyon provides the clustering, orchestration, service discovery, package management, HTTP proxy, and web UI.

* Fermyon uses the Nomad scheduler to schedule Spin applications across a cluster.
* Along with Nomad, Fermyon uses Consul for service discovery
* Fermyon runs a [Bindle](https://www.fermyon.com/blog/bindle-what-is-it) server to provide package management in the Spin data plane.
* HTTP proxying is provided by Traefik
* And the web UI for Spin is provided by Hippo

While the Fermyon installer creates a single-node cluster, you can scale up  Nomad to as many workers as you would like. Future versions of the AWS installer will likely support more complex roll-outs.

## Installing Fermyon

Fermyon can be installed in a few ways:

- Use a shell installer to [run a version locally](/quickstart-local)
- Use Terraform to deploy to your preferred cloud:
  - Here's how to [get up and running on a single Amazon EC2 instance](/quickstart-aws)
  - There is also a [multi-node configuration for AWS](https://github.com/fermyon/installer/tree/main/aws/terraform/multiple-nodes)
  - There are also quick-starts for [Azure](https://github.com/fermyon/installer/tree/main/azure/README.md),
    [DigitalOcean](https://github.com/fermyon/installer/tree/main/digitalocean/README.md) and [GCP](https://github.com/fermyon/installer/tree/main/gcp/README.md)

Don't want to install Fermyon on your own account? Try out [Fermyon Cloud](https://www.fermyon.com/cloud), our hosted option.
