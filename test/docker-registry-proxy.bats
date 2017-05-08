#!/usr/bin/env bats

teardown() {
  /usr/sbin/nginx -s stop
  pkill tail
  rm /etc/nginx/conf.d/docker-registry-proxy.htpasswd || true
  rm /etc/nginx/sites-enabled/docker-registry-proxy || true
  rm -rf /etc/nginx/ssl || true
  rm /var/log/nginx/access.log || true
  rm /var/log/nginx/error.log || true
}

@test "docker-registry-proxy uses an nginx version >= 1.7.5" {
  # We need at least 1.7.5 for built-in handling of chunked transfer encoding (1.3.9)
  # and support for the "always" parameter in the "add_header" directive (1.7.5).
  run apk-install dpkg && \
      dpkg --compare-versions `/usr/sbin/nginx -v 2>&1 | grep -oE "\d+.\d+.\d+"` ">=" "1.7.5" &&
      apk del dpkg
  [ "$status" -eq 0 ]
}

@test "docker-registry-proxy requires the AUTH_CREDENTIALS environment variable to be set" {
  export REGISTRY_PORT=tcp://172.17.0.70:5000
  export DOCKER_REGISTRY_TAG=latest
  run timeout -t 1 /bin/bash run-docker-registry-proxy.sh
  [ "$status" -eq 1 ]
  [[ "$output" =~ "AUTH_CREDENTIALS" ]]
}

@test "docker-registry-proxy requires the REGISTRY_PORT environment variable to be set" {
  export AUTH_CREDENTIALS=foobar:password
  export DOCKER_REGISTRY_TAG=latest
  run timeout -t 1 /bin/bash run-docker-registry-proxy.sh
  [ "$status" -eq 1 ]
  [[ "$output" =~ "REGISTRY_PORT" ]]
}

@test "docker-registry-proxy configures a v1 registry proxy if DOCKER_REGISTRY_TAG is omitted" {
  export AUTH_CREDENTIALS=foobar:password
  export REGISTRY_PORT=tcp://172.17.0.70:5000
  timeout -t 1 /bin/bash run-docker-registry-proxy.sh || true
  run bash -c "ls /etc/nginx/sites-enabled | wc -l"
  [[ "$output" == "1" ]]
  run cat /etc/nginx/sites-enabled/docker-registry-proxy
  [[ "$output" =~ "location /v1" ]]
  [[ ! "$output" =~ "location /v2" ]]
}

@test "docker-registry-proxy configures a v1 registry proxy if DOCKER_REGISTRY_TAG=latest" {
  export AUTH_CREDENTIALS=foobar:password
  export REGISTRY_PORT=tcp://172.17.0.70:5000
  export DOCKER_REGISTRY_TAG=latest
  timeout -t 1 /bin/bash run-docker-registry-proxy.sh || true
  run bash -c "ls /etc/nginx/sites-enabled | wc -l"
  [[ "$output" == "1" ]]
  run cat /etc/nginx/sites-enabled/docker-registry-proxy
  [[ "$output" =~ "location /v1" ]]
  [[ ! "$output" =~ "location /v2" ]]
}

@test "docker-registry-proxy configures a v2 registry proxy if DOCKER_REGISTRY_TAG=2" {
  export AUTH_CREDENTIALS=foobar:password
  export REGISTRY_PORT=tcp://172.17.0.70:5000
  export DOCKER_REGISTRY_TAG=2
  timeout -t 1 /bin/bash run-docker-registry-proxy.sh || true
  run bash -c "ls /etc/nginx/sites-enabled | wc -l"
  [[ "$output" == "1" ]]
  run cat /etc/nginx/sites-enabled/docker-registry-proxy
  [[ ! "$output" =~ "location /v1" ]]
  [[ "$output" =~ "location /v2" ]]
}

@test "docker-registry-proxy configures a v2 registry proxy if DOCKER_REGISTRY_TAG=2.2" {
  export AUTH_CREDENTIALS=foobar:password
  export REGISTRY_PORT=tcp://172.17.0.70:5000
  export DOCKER_REGISTRY_TAG=2.2
  timeout -t 1 /bin/bash run-docker-registry-proxy.sh || true
  run bash -c "ls /etc/nginx/sites-enabled | wc -l"
  [[ "$output" == "1" ]]
  run cat /etc/nginx/sites-enabled/docker-registry-proxy
  [[ ! "$output" =~ "location /v1" ]]
  [[ "$output" =~ "location /v2" ]]
}
