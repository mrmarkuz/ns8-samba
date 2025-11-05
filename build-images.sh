#!/bin/bash

set -e
images=()

repobase="${REPOBASE:-ghcr.io/nethserver}"
user_manager_version=v1.2.4

podman build --target ubuntu-samba-base -t ${repobase}/ubuntu-samba:latest .
podman build --squash -t ${repobase}/samba-dc .
images+=("${repobase}/samba-dc")

#
# Imageroot samba
#
container=$(buildah from scratch)
reponame="samba"

# Reuse existing nodebuilder-samba container, to speed up builds
if ! buildah containers --format "{{.ContainerName}}" | grep -q nodebuilder-samba; then
    echo "Pulling NodeJS runtime..."
    buildah from --name nodebuilder-samba -v "${PWD}:/usr/src:Z" docker.io/library/node:22.13.1-slim
fi

echo "Downloading user manager ${user_manager_version} UI..."
curl -f -O -L https://github.com/NethServer/ns8-user-manager/releases/download/${user_manager_version}/ns8-user-manager-${user_manager_version}.tar.gz

echo "Build static UI files with node..."
buildah run \
    --workingdir=/usr/src/ui \
    --env="NODE_OPTIONS=--openssl-legacy-provider" \
    nodebuilder-samba \
    sh -c "yarn install && yarn build"

buildah add "${container}" imageroot /imageroot
buildah add "${container}" ns8-user-manager-${user_manager_version}.tar.gz /imageroot/api-moduled/public
buildah add "${container}" ui/dist /ui
buildah config \
    --label="org.nethserver.max-per-node=1" \
    --label="org.nethserver.min-core=3.9.0-0" \
    --label "org.nethserver.images=${repobase}/samba-dc:${IMAGETAG:-latest} docker.io/timescale/timescaledb:2.23.0-pg17" \
    --label 'org.nethserver.authorizations=node:fwadm cluster:accountprovider traefik@node:routeadm' \
    --label="org.nethserver.tcp-ports-demand=1" \
    --entrypoint=/ "${container}"
buildah commit "${container}" "${repobase}/${reponame}"
images+=("${repobase}/${reponame}")

#
#
#

if [[ -n "${CI}" ]]; then
    # Set output value for Github Actions
    printf "images=%s\n" "${images[*],,}" >> "${GITHUB_OUTPUT}"
else
    printf "Publish the images with:\n\n"
    for image in "${images[@]}"; do printf "  buildah push %s docker://%s:latest\n" "${image}" "${image}" ; done
    printf "\n"
fi
