In order to support a wide range of Linux distrobutions, we build a release of
bindle that uses a widely-supported version of glibc and statically-links
OpenSSL 1.1 (to support newer distros that only ship OpenSSL 3).

In the event that you need to compile for a target platform other than the
current host's architecture you can adjust the PLATFORM variable in the script below.

```bash
PLATFORM=linux/amd64
mkdir -p "./${PLATFORM}"
DOCKER_BUILDKIT=1 docker build --platform ${PLATFORM} -o ./${PLATFORM} -f Dockerfile.bindle-static .
```
