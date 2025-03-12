#!/bin/bash

set -e
images=()

repobase="${REPOBASE:-ghcr.io/nethserver}"
reponame="ubuntu-samba"
user_manager_version=v1.1.2

container="ubuntu-working-container"
# Prepare a local Ubuntu-based samba image
if ! buildah inspect --type container "${container}" &>/dev/null; then
    container=$(buildah from --name "${container}" docker.io/library/ubuntu:24.04)
    buildah run "${container}" -- bash <<'EOF'
set -e
apt-get update
apt-get -y install samba winbind krb5-user iputils-ping bzip2 ldb-tools chrony dnsutils acl smbclient libnss-winbind rsync plocate
apt-get clean
find /var/lib/apt/lists/ -type f -delete
EOF
    buildah commit "${container}" "${repobase}/${reponame}"
fi

#
# Add our entrypoint script to build samba-dc
#
container=$(buildah from "${repobase}/${reponame}")
reponame="samba-dc"
buildah run "${container}" -- mv -v /etc/samba/smb.conf /etc/samba/smb.conf.distro
buildah add "${container}" samba-dc/ /
buildah config \
    --env=SAMBA_LOGLEVEL="1 auth_audit:3" \
    --env=SAMBA_SHARES_DIR=/srv/shares \
    --env=SAMBA_HOMES_DIR=/srv/homes \
    "${container}"
buildah run "${container}" -- bash <<'EOF'
mkdir -m 0755 -p "${SAMBA_SHARES_DIR:?}" "${SAMBA_HOMES_DIR:?}"
chown -c root:root "${SAMBA_SHARES_DIR}" "${SAMBA_HOMES_DIR}"
# Verify our assumptions on the uid/gid numeric value of some well-known entries
[[ "$(id -u nobody)" == 65534 ]] || : ${nobody_uid_error:?Unexpected nobody uid value}
[[ "$(id -g nobody)" == 65534 ]] || : ${nobody_gid_error:?Unexpected nobody gid value}
[[ "$(getent group users | cut -d: -f3)" == 100 ]] || : ${users_gid_error:?Unexpected users gid value}
echo "OS" $(grep -E '^(NAME|VERSION)=' /etc/os-release)
echo "Samba" $(samba -V)
# Initialize an empty directory as homedir skeleton.
mkdir -vp /var/lib/samba/skel.d
# Ubuntu HOME_MODE default value is too wide for this application.
sed -r -i '/^HOME_MODE/ s/\b0750\b/0700/' /etc/login.defs
EOF
buildah config --cmd='' \
    --entrypoint='["/entrypoint.sh"]' \
    --volume=/srv/shares \
    --volume=/srv/homes \
    --volume=/var/lib/samba \
    --volume=/etc/samba \
    "${container}"
buildah commit "${container}" "${repobase}/${reponame}"
images+=("${repobase}/${reponame}")

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
    --label="org.nethserver.min-core=3.3.0-0" \
    --label "org.nethserver.images=ghcr.io/nethserver/samba-dc:${IMAGETAG:-latest}" \
    --label 'org.nethserver.authorizations=node:fwadm ldapproxy@node:accountprovider cluster:accountprovider traefik@node:routeadm' \
    --label="org.nethserver.tcp-ports-demand=1" \
    --label 'org.nethserver.flags=core_module account_provider' \
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
