--
-- Copyright (C) 2025 Nethesis S.r.l.
-- SPDX-License-Identifier: GPL-3.0-or-later
--

-- Enable TimescaleDB extension
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Create the table for Samba audit logs
CREATE TABLE samba_audit (
    time        TIMESTAMPTZ       NOT NULL DEFAULT now(),
    proto       TEXT,
    username    TEXT,
    addr        TEXT,
    share       TEXT,
    op          TEXT,
    result      TEXT,
    path        TEXT,
    aux         TEXT
);

-- Convert to hypertable
SELECT create_hypertable('samba_audit', 'time');

-- (Optional) Enable compression
ALTER TABLE samba_audit SET (timescaledb.compress, timescaledb.compress_segmentby = 'share');

-- Add compression policy: compress data older than 30 days
SELECT add_compression_policy('samba_audit', INTERVAL '30 days');

-- (Optional) Indexes to improve inserts and queries
CREATE INDEX ON samba_audit(time DESC);
CREATE INDEX ON samba_audit(share);
CREATE INDEX ON samba_audit(username);
CREATE INDEX ON samba_audit(op);

