# Deploying to Fermyon

Once Fermyon is up and running via your
[installer of choice](./README.md#installers) and you've prepared your
environment with relevant values for Hippo and Bindle, you're ready to deploy
your first app.

## Prerequisites

For building and deploying Spin apps on Fermyon, you'll need the
[Spin CLI](https://spin.fermyon.dev/quickstart).

## Example flow

First, install the example application templates via Spin:

```console
$ spin templates install --git https://github.com/fermyon/spin
Copying remote template source
Installing template redis-rust...
Installing template http-rust...
Installing template http-go...
Installing template redis-go...
Installed 4 template(s)

+---------------------------------------------------+
| Name         Description                          |
+===================================================+
| http-go      HTTP request handler using (Tiny)Go  |
| http-rust    HTTP request handler using Rust      |
| redis-go     Redis message handler using (Tiny)Go |
| redis-rust   Redis message handler using Rust     |
+---------------------------------------------------+
```

Here we'll choose the `http-rust` example and create a new app:

```console
$ spin new http-rust myapp
Project description: My first Fermyon app
HTTP base: /
HTTP path: /hello
```

You're ready to navigate into the app directory and build it from source:

```console
$ cd myapp/

$ spin build
<build output omitted>
```

Finally, you are ready to deploy:

```console
$ spin deploy
Deployed myapp version 0.1.0+q65c7318
Available Routes:
  myapp: http://spin-deploy.myapp.local.fermyon.link/hello
```

You can then hit your app's served route (`/hello`) via its URL.

```console
$ curl http://spin-deploy.myapp.local.fermyon.link/hello
Hello, Fermyon
```

You can also find the app URL by navigating to the Hippo dashboard (`$HIPPO_URL`), loggging in
with the `$HIPPO_USERNAME` and `$HIPPO_PASSWORD` values and then clicking on the app page.

Congratulations, you've deployed your first Fermyon app!

## Deploying new versions of your app

Making changes to your app is as easy as updating the source code, re-building
and re-deploying.

To see this in practice, update the message to `Hello, Fermyon!` in the app's
source code and save your changes. After a fresh build and deploy, the
new version of your app will be live:

```console
$ spin build
<build output omitted>

$ spin deploy
Deployed myapp version 0.1.0+qdb204e5
Available Routes:
  myapp: http://spin-deploy.myapp.local.fermyon.link/hello

$ curl http://spin-deploy.myapp.local.fermyon.link/hello
Hello, Fermyon!
```

## Wrapping up

In this guide, we walked through deploying multiple versions of your first
application on Fermyon.

We hope this experience inspires you to explore further. For in-depth guides
and further information, see the
[Spin documentation](https://spin.fermyon.dev/) or
[Hippo documentation](https://docs.hippofactory.dev/).