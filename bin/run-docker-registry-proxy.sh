#!/bin/bash
# Make sure required environment variables are set.
if [ ! -f /etc/nginx/conf.d/docker-registry-proxy.htpasswd ]; then
  : ${AUTH_CREDENTIALS:?"Error: environment variable AUTH_CREDENTIALS should be populated with a comma-separated list of user:password pairs. Example: \"admin:pa55w0rD\"."}
fi

# Make sure a registry is linked in to this container
: ${REGISTRY_PORT:?"Error: a registry container must be linked into this container (--link REGISTRY_CONTAINER_NAME:registry)"}

# Parse auth credentials, add to a htpasswd file.
if [ ! -f /etc/nginx/conf.d/docker-registry-proxy.htpasswd ]; then
    AUTH_PARSER="
    create_opt = 'c'
    ENV['AUTH_CREDENTIALS'].split(',').map do |creds|
      user, password = creds.split(':')
      %x(htpasswd -b#{create_opt} /etc/nginx/conf.d/docker-registry-proxy.htpasswd #{user} #{password})
      create_opt = ''
    end"
    ruby -e "$AUTH_PARSER" || \
    (echo "Error creating htpasswd file from credentials '$AUTH_CREDENTIALS'" && exit 1)
fi

# Parse address of registry server from the linked REGISTRY_PORT environment variable.
export REGISTRY_SERVER="${REGISTRY_PORT##*/}"

# Generate the NGiNX configuration.
if [[ "${DOCKER_REGISTRY_TAG:0:1}" == "2" ]]; then
  export REGISTRY_TEMPLATE=docker-registry-proxy-v2.erb
else
  export REGISTRY_TEMPLATE=docker-registry-proxy.erb
fi
erb -T 2 "./$REGISTRY_TEMPLATE" > /etc/nginx/sites-enabled/docker-registry-proxy || \
  (echo "Error creating nginx configuration." && exit 1)

# Start NGiNX, tail error and access logs.
/usr/sbin/nginx
touch /var/log/nginx/access.log /var/log/nginx/error.log
tail -fq /var/log/nginx/access.log /var/log/nginx/error.log
