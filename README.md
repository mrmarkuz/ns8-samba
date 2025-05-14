# samba

The Samba module allows the creation of multiple AD domains within an NS8
cluster. An AD domain (or *realm*, in Kerberos terms) can have one or more
domain controllers (DCs). Alternatively, Samba can be configured as a
File Server joined to an existing Active Directory domain.

A Samba module instance requires a dedicated IP address and binds to
well-known TCP ports. Multiple instances cannot run on the same system due
to TCP port conflicts.

**Do not assign an IP address from an untrusted network!** The IP address
assigned to a Samba instance exposes internal services that are not
designed to be publicly accessible. This IP is automatically added to the
cluster VPN routes, allowing Samba instances to reach domain controllers
for replication and authentication.

The LDAP service of Samba DCs does not support clear-text LDAP binds. You
must enable TLS or use Kerberos/GSSAPI authentication in external
applications. Cluster modules must connect to the Samba LDAP service
through the local `Ldapproxy` instance. See the core documentation for
more details about Ldapproxy.

## Installation

As Samba binds to well-known TCP/UDP ports, only one instance can run on
each node.

To run a Samba instance as an account provider, install it using the
`add-internal-provider` action:

    api-cli run add-internal-provider --data '{"image":"samba","node":1}'

To run a File Server without Domain Controller services, install it like
any other module:

    add-module samba 1

## Provision

After installation, the module must be provisioned with domain data before
starting its services. The `configure-module` action supports three types
of provisioning:

1. `new-domain` (role `dc`): Initializes the first DC of a new Active Directory domain.
2. `join-domain` (role `dc`): Joins an additional DC to an existing domain.
3. `join-member` (role `member`): Joins an existing AD domain as a File Server.

Example: provision a new domain:

    api-cli run module/samba1/configure-module --data - <<EOF
    {
        "provision":"new-domain",
        "adminuser":"administrator",
        "adminpass":"Nethesis,1234",
        "realm":"ad.$(hostname -d)",
        "nbdomain":"DP",
        "hostname":"dc1",
        "ipaddress":"10.133.0.2"
    }
    EOF

To join another instance to the same domain:

    api-cli run module/samba2/configure-module --data - <<EOF
    {
        "provision":"join-domain",
        "adminuser":"administrator",
        "adminpass":"Nethesis,1234",
        "realm":"ad.$(hostname -d)",
        "hostname":"dc2",
        "ipaddress":"10.124.0.2"
    }
    EOF

To join a File Server as a member of the domain:

    api-cli run module/samba3/configure-module --data - <<EOF
    {
        "provision":"join-member",
        "adminuser":"administrator",
        "adminpass":"Nethesis,1234",
        "realm":"ad.$(hostname -d)",
        "hostname":"fs1",
        "ipaddress":"10.143.0.2"
    }
    EOF

## IP routing for the AD domain

In domains with multiple DCs, domain controllers must communicate to join
the domain and replicate data. If a DC cannot reach others, provisioning
will fail.

When a DC’s IP address is not directly reachable from other nodes, the
system automatically configures routing through the cluster VPN. This is
common when DCs are deployed in different networks.

To check VPN routing for domain controller IPs:

    wg
    ip route

Routing changes are handled by this command:

    apply-vpn-routes

It updates both system routing and WireGuard configuration. It runs
automatically at system startup and whenever VPN settings change, so
manual use is rarely needed.

See also the [Core VPN documentation](https://nethserver.github.io/ns8-core/core/vpn/#vpn).

## Create a new user account

To create a new user and assign them to the `developers` group:

    api-cli run module/samba1/add-user --data - <<EOF
    {
      "user": "alice",
      "display_name": "Alice Jordan",
      "password": "secret",
      "locked": false,
      "groups": [
          "developers"
      ]
    }
    EOF

## User management web portal

When acting as a DC, the Samba module provides a public web portal where
AD users can authenticate and change their passwords.

The module registers a Traefik path route, using the domain name as a
suffix, e.g.:

    https://<node FQDN>/users-admin/domain.test/

This service is advertised under the name `users-admin` and can be
discovered using the standard mechanisms. For example:

    api-cli run module/mymodule1/list-service-providers  --data '{"service":"users-admin", "filter":{"domain":"dp.nethserver.net","node":"1"}}'

The event `service-users-admin-changed` is triggered when the service
becomes available or is updated.

The module backend runs under the `api-moduled.service` Systemd unit. See
`api-moduled` documentation (from the `ns8-core` repository) for details.

API implementation files are located under
`imageroot/api-moduled/handlers/`, and mapped to:

    https://<node FQDN>/users-admin/domain.test/api/

`.json` files in that directory define API schemas (input/output) using
JSON Schema. These files describe the request and response formats.

## File Server

Any Samba instance (whether its role is `dc` or `member`) can act as a
**file server**, provided it uses a **private network** IP address.
Windows-compatible clients can access shared folders and home directories
using domain credentials (guest access is not supported).

- A user's home directory is created in the `homes` volume when they log in.

- Shared folders are managed through the file server API and stored in the
  `shares` volume. If a shared folder has the same name as a domain user,
  that user's home directory becomes inaccessible.

  + `list-shares`
  + `add-share`, `alter-share`, `remove-share`
  + `reset-share-acls`

If Samba runs as a DC and is bound to the **internal VPN interface** (see
the `ipaddress` attribute in the Provision section), it will be
**inaccessible** to clients from other networks.

## Samba Audit

User activity on shared folders is recorded in a TimescaleDB instance.

Access TimescaleDB on port 15432 as user `postgres` (full privileges) or
`samba_audit` (select-only privileges). Passwords are saved into
`state/timescaledb.env`

By default, no events from the Samba `vfs_full_audit` module are logged.
Audit logging must be explicitly enabled per share using the share
management actions. For example:

    api-cli run module/samba1/alter-share --data '{"name":"myshare","enable_audit":true}'

To include failed access attempts in the audit log, add the
`log_failed_events` attribute:

    api-cli run module/samba1/alter-share --data '{"name":"myshare","enable_audit":true,"log_failed_events":true}'

The following events are logged to TimescaleDB by default:

* **Success events**: `create_file unlinkat renameat mkdirat fsetxattr`
* **Failure events**: `create_file openat unlinkat renameat mkdirat
  fsetxattr`

You can override these defaults using the following environment variables:

* `SAMBA_AUDIT_SUCCESS`
* `SAMBA_AUDIT_FAILURE`

For example, to log all successful events, add the following line to the
`state/environment` file:

    SAMBA_AUDIT_SUCCESS=all

The change takes effect the next time an `alter-share` or `add-share`
action is executed.

Review the current audit settings with this command:

    podman exec samba-dc net conf list

## Restore from backup

The module backup contains shared folders, home dirs and DC state.

For a single DC domain, run the restore on a system with the original DC
IP address. If this is not the case, the restore procedure configures the
restored DC with the node VPN IP address. Then use `set-ipaddress` action
to change the DC IP address. Network clients must be reconfigured to find
the AD DNS server! For instance:

    api-cli run module/samba1/set-ipaddress --data '{"ipaddress": "10.15.21.100"}'

In a domain with multiple domain controllers, DC state is replicated. In
case of a node failure it is not necessary to restore from backup unless
the failing node is also a file server. In this case the restore procedure
only extracts the contents of home directories and shared folders from the
backup set. When the procedure completes, go to the ``Domain and users``
page and resume the configuration of the DC: it must be joined to the
domain as a new DC.

## Migration notes

Migration is implemented in the `import-module` action.

- The NS7 DC role is transferred to NS8 by copying `/var/lib/samba` dir
  contents. The NS7 file-server role can be transferred to NS8 too.
- If file-server role is migrated, the host name is retained as a NetBIOS
  alias and a DNS CNAME record, pointing to the DC host name.
- The migration procedure synchronizes the existing Posix ACLs of shared
  folders. A special backward-compatible configuration is applied to
  shares created by the migration procedure. The `samba-reset-acls`
  command clears that special configuration, too.
- Home directories are migrated like shared folders. Shared folders have
  higher priority over home dirs: if a shared folder has the same name of
  a domain user, the home directory cannot be accessed.
- Guest access does not work in NS8, because it is [not implemented by the
  Samba DC
  role](https://wiki.samba.org/index.php/FAQ#How_Do_I_Enable_Guest_Access_to_a_Share_on_a_Samba_AD_DC.3F)
- `user.SAMBA_PAI` attribute is not copied to NS8 shares. It contains
  the ACL *protected/don't inherit* flag. See [map acl
  inherit](https://www.samba.org/samba/docs/current/man-html/smb.conf.5.html).
