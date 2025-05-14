#!/bin/sh

#
# Copyright (C) 2025 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later
#

psql -v ON_ERROR_STOP=1 --set "pass=${SAMBA_AUDIT_PASSWORD:?}" --username "${POSTGRES_USER:?}" <<-'EOSQL'
\c samba_audit
CREATE USER samba_audit WITH PASSWORD :'pass';
GRANT USAGE ON SCHEMA public TO samba_audit;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO samba_audit;
EOSQL
