#!/bin/sh

#
# Copyright (C) 2025 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later
#

#
# Reference https://docs.timescale.com/self-hosted/latest/backup-and-restore/logical-backup/#back-up-and-restore-an-entire-database
#

psql -v ON_ERROR_STOP=1 --set "pass=${SAMBA_AUDIT_PASSWORD:?}" --username "${POSTGRES_USER:?}" <<-'EOSQL'
\c samba_audit
CREATE USER samba_audit WITH PASSWORD :'pass';
GRANT USAGE ON SCHEMA public TO samba_audit;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO samba_audit;
CREATE EXTENSION IF NOT EXISTS timescaledb;
SELECT timescaledb_pre_restore();
EOSQL

pg_restore -Fc -d samba_audit

psql --username "${POSTGRES_USER:?}" <<-'EOSQL'
\c samba_audit
SELECT timescaledb_post_restore();
EOSQL

# Print additional information:
psql --version

# The script is sourced, stop temp server and exit
docker_temp_server_stop
exit 0

