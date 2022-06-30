title = "Running Fermyon on AWS"
date = "2022-06-08T14:05:02.118466Z"

[extra]
url = "https://github.com/fermyon/fermyon.dev/blob/main/content/quickstart-aws.md"
---

Thank you for trying out the AWS installer of Fermyon! This document will guide
you through configuring Fermyon on AWS.

<iframe width="560" height="315" src="https://www.youtube.com/embed/rrkF8A_Ww5A" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>

# Setup
> [Please read the security disclaimer before continuing.](https://github.com/fermyon/installer/tree/main/aws#security-disclaimer)

- Log in to your AWS account. [See installer documentation for AWS account setup](https://github.com/fermyon/installer/tree/main/aws#prerequisites).
- Install the [terraform CLI](https://learn.hashicorp.com/tutorials/terraform/install-cli#install-terraform).

Clone the [installer repository](https://github.com/fermyon/installer) and `cd` in to the `aws/terraform` directory.

```console
git clone https://github.com/fermyon/installer.git
cd installer/aws/terraform
```

Initialize terraform and deploy the infrastructure with Let's Encrypt to provision certs for HTTPS. See [this page](https://github.com/fermyon/installer/tree/main/aws#resources-deployed) for details about the resources that will be deployed in AWS.

```console
terraform init
terraform apply -var='enable_letsencrypt=true'
```

> This step can take about a few minutes to complete.

If everything is successful, you should see the links for the relevant dashboards and
environment variables that need to be added to your current shell. See the [troubleshooting guide](https://github.com/fermyon/installer/tree/main/aws#troubleshootingdebugging) for help with deployment issues.

Source your environment using:

```console
$(terraform output -raw environment)
```

For a more detailed walkthrough, make sure to visit [this page](https://github.com/fermyon/installer/tree/main/aws).

### Deploying your first application to Fermyon on AWS

Spin provides templates to bootstrap a new application. Let's use the `http-rust` template to create
a simple hello world HTTP application written in Rust.

```console
$ spin new http-rust hello-fermyon-aws
Project description: AWS quickstart demo
HTTP base: /
HTTP path: /...
$ cd hello-fermyon-aws
```

Now we can build our application using `spin build`:
```console
$ spin build
Executing the build command for component hello-fermyon-aws: cargo build --target wasm32-wasi --release
...
Successfully ran the build command for the Spin components.
```

The application has been built, and is now ready to be deployed to Fermyon.

> NOTE: Ensure the `HIPPO_URL`, `HIPPO_USERNAME`, `HIPPO_PASSWORD` and `BINDLE_URL` environment variables are set
in the terminal by running `$(terraform output -raw environment)`.

```console
$ spin deploy
Deployed hello-fermyon-aws version 0.1.0+qe86e210
Available Routes:
  hello-fermyon-aws: https://spin-deploy.hello-fermyon-aws.hippo.3.226.70.241.sslip.io (wildcard)
```

Fermyon automatically configured the domain for the application, and the application
now accepts requests:

```console
$ curl -i https://spin-deploy.hello-fermyon-aws.hippo.3.226.70.241.sslip.io/
HTTP/2 200
date: Fri, 17 Jun 2022 16:40:34 GMT
foo: bar
content-type: text/plain; charset=utf-8
content-length: 14

Hello, Fermyon
```

Log in to the Hippo dashboard where you can see details about the new application, view the logs, or change environment variables:

```console
$ echo $HIPPO_URL
https://hippo.3.226.70.241.sslip.io
```

![The new application](static/image/docs/hippo-app-aws.png)

> For a detailed guide on writing applications for the Fermyon platform, visit
> the [Spin website](https://spin.fermyon.dev).

You can now make changes to the application and run `spin deploy` again, or
create new applications.

To uninstall the Fermyon and all related AWS resources:
```console
terraform destroy
```
