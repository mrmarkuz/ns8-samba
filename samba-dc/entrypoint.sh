#!/bin/bash

#
# Copyright (C) 2022 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later
#

set -e

function domain_controller_role ()
{
    ntp_signd="/var/lib/samba/ntp_signd"
    extra_args=()
    if [[ -n "${DNS_FORWARDER}" ]]; then
        extra_args+=("--option=dns forwarder=${DNS_FORWARDER}")
    fi

    if [[ ! -d "${ntp_signd}" ]]; then
        mkdir -v -m 0750 "${ntp_signd}"
    fi
    chgrp -c _chrony "${ntp_signd}"

    samba -F --debug-stdout "${extra_args[@]}" &
    chronyd -d -x &
    wsdd -i "${IPADDRESS}" -d "${NBDOMAIN}" &
    wait -n
    exit $?
}

function member_server_role ()
{
    wsdd -i "${IPADDRESS}" -d "${NBDOMAIN}" &
    smbd -F --debug-stdout &
    winbindd -F --debug-stdout &
    nmbd -F --debug-stdout &
    wait -n
    exit $?
}

#
# Expand configuration and start services
#

expand-config

if [ $# -gt 0 ]; then
    exec "${@}"
fi

testparm -s 2>/dev/null
if [ "${SERVER_ROLE}" == "member" ] ; then
    member_server_role
else
    domain_controller_role
fi
