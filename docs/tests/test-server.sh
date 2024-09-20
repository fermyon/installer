#!/bin/bash
set -euo pipefail

spin up &
pid=$!

timeout 10s bash -c 'until curl -q 127.0.0.1:3000 &>/dev/null; do sleep 1; done'

resp_code=$(curl -o /dev/null -s -w "%{http_code}\n" 127.0.0.1:3000)
[[ "${resp_code}" == "302" ]] && \
  (echo "Success: server returned 302" && kill ${pid}) || \
  (echo "Failure: unexpected response code: ${resp_code}" && kill ${pid} && exit 1)