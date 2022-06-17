In order to support a wide range of Linux distrobutions, we build a release of
bindle that uses a widely-supported version of glibc and statically-links
OpenSSL 1.1 (to support newer distros that only ship OpenSSL 3).

```bash
$ DOCKER_BUILDKIT=1 docker build -o . -f Dockerfile.bindle-static .
```
