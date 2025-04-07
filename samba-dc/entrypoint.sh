#!/bin/bash

#
# Copyright (C) 2022 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later
#

set -e

expand-config

ntp_signd="/var/lib/samba/ntp_signd"

if [ $# -eq 0 ]; then
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
else
    exec "${@}"
fi
