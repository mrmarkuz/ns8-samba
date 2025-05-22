# samba-dc

This image provides a Samba Domain Controller (DC) providing also File
Server functionality. Read carefully the Samba Wiki section about [using a
DC as a file
server](https://wiki.samba.org/index.php/Setting_up_Samba_as_an_Active_Directory_Domain_Controller#Using_the_Domain_Controller_as_a_File_Server_.28Optional.29)
to understand its limitations.

As alternative the image can run also in File Server mode without DC
services (e.g. DNS, Kerberos, LDAP). See also [Samba "member server"
role](https://wiki.samba.org/index.php/Setting_up_Samba_as_a_Domain_Member).

## TCP/UDP ports

The container uses the following ports:

- `53/tcp`, `53/udp`, DNS
- `88/tcp`, `88/udp`, Kerberos
- `123/udp`, NTP
- `135/tcp`, End Point Mapper (DCE/RPC Locator Service)
- `137/udp`, NetBIOS Name Service
- `138/udp`, NetBIOS Datagram
- `139/tcp`, NetBIOS Session
- `389/tcp`, `389/udp`, LDAP
- `445/tcp`, SMB over TCP
- `464/tcp`, `464/udp`, Kerberos kpasswd
- `636/tcp`, LDAPS
- `3268/tcp`, Global Catalog
- `3269/tcp`,  Global Catalog SSL
- `15432/tcp`, TimescaleDB for Audit Log
- `49152-65535/tcp` Dynamic RPC Ports

## Volumes

- `config`, mounted on `/etc/samba`.
- `data`, contains Samba databases and the default `sysvol` and
  `netlogon` shares. Mounted on `/var/lib/samba`.
- `shares`, storage of shared folders, mounted on `/srv/shares`.
- `homes`, home directories, mounted on `/srv/homes`.

## Environment variables

The following environment variables are expected to run the normal
container services. Some commands can expect more variables: see the
individual command documentation for more information.

- `IPADDRESS`, bind services to this IPv4 address (in addition to 127.0.0.1)
- `PREFIXLEN`, if the network devices does not provide network information
  (e.g. VPN, point-to-point) set this variable to the netmask length. If
  this variable is set, NetBIOS is implicitly disabled.
- `NBDOMAIN`, the NT-style domain name
- `REALM`, the domain name for Kerberos and DNS configuration
- `DNS_FORWARDER`, if present its value is added as `dns forwarder` among
  samba startup options.
- `SAMBA_SHARES_DIR`, default `/srv/shares`: path to the volume containing
  shared folders. Do not change it! In any case do not put it under
  `/var/lib/samba` to avoid conflicts with the backup procedure.
- `SAMBA_HOMES_DIR`, default `/srv/homes`: path to the volume containing
  user home directories. Do not change it! In any case do not put it under
  `/var/lib/samba` to avoid conflicts with the backup procedure.
- `SAMBA_LOGLEVEL`, default `1`: value for the `log level` configuration
  directive.
- `SERVER_ROLE`, switch the server role between `dc` (default) and `member`
- `DNS1ADDRESS`, `DNS2ADDRESS`, set IP addresses of DNS servers for domain
  member role.

## Custom configuration

To override the container configuration, write custom `smb.conf`
directives in the `include.conf` file, under the `config` volume root. It
corresponds to this container path:

    /etc/samba/include.conf

## `entrypoint.sh`

The container entrypoint in any case runs the `expand-config` command, to
properly initialize the container configuration files.

Arguments passed to the container entrypoint are interpreted as an
additional command to execute. This behavior is required to run
`new-domain`, `join-domain` and `join-member` provisioning procedures.

If no arguments are passed, the services of the configured role are started.

- Services of role `dc` (default): `samba`, `chronyd`, `wsdd`.
- Services of role `member`: `smbd`, `nmbd`, `winbindd`, `wsdd`.

## Commands

Commands are installed under `/usr/local/sbin`.

### `expand-config`

The `expand-config` command is executed by the container entrypoint. It
writes the following configuration files, based on the values of the
container environment variables.

- `/etc/hosts`
- `/etc/krb5.conf`
- `/etc/samba/smb.conf`
- `/etc/resolv.conf`

### `new-domain`

This command is designed to run as the container entrypoint argument. Eg.

    podman run --env=ADMINCREDS ... --volume data:/var/lib/samba:z ... samba-dc:latest new-domain

The Samba DC services are not started at all, instead the command clears
the `smb.conf` file and starts a new domain provision procedure. If the
procedure is successful the command terminates with `0` exit code and the
volumes are left ready for starting the DC.

Apart from common environment variables, it expects to read the
credentials of a `Domain Admins` member from the environment variable
`ADMINCREDS`. If that user does not exist, it is created, assigned the
password, and added to `Domain Admins` on the fly.

The `ADMINCREDS` environment variable format must be a base64-encoded TSV
record with this format:

    <ADMIN_NAME> <TAB> <ADMIN_PASSWORD>

Also the credentials of a service user are expected in the environment
variables `SVCUSER` and `SVCPASS`. This user is granted standard
privileges and its password is set with "no-expire" flag.

### `join-domain`

This command is designed to run as the container entrypoint argument. Eg.

    podman run --env=JOINADDRESS ... --volume data:/var/lib/samba:z ... samba-dc:latest join-domain

Similarly to `new-domain`, it expects the `ADMINCREDS` variable is
present. This time the credentials are presented to join a new DC to an
existing AD domain. The user must be already granted the domain join
permissions: usually a member of the `Domain Admins` group is used for
this purpose.

The additional `JOINADDRESS` variable must be contain the IP address of an
existing DC. It is used as container DNS resolver to run the join
procedure.

Like the `new-domain` command, if `join-domain` terminates with exit-code
`0` the volumes are left ready for starting the DC.

### `join-member`

This command is designed to run as the container entrypoint argument. Eg.

    podman run --env=SERVER_MODE=member --env=DNS1ADDRESS=10.5.4.1 ... --volume data:/var/lib/samba:z ... samba-dc:latest join-member

Like `join-domain` it expects `ADMINCREDS=` is set to join the domain as a
member server. The `SERVER_MODE=member` ensures that configuration files
are written specifically for the "member server" Samba role, as documented
in Samba Wiki page. For this purpose, the `DNS1ADDRESS=` must be set too.

### `samba-add-share`

Create a new directory under `SAMBA_SHARES_DIR` and add it to the Samba
registry as a new share.

Adding a new share implicitly invokes `samba-reset-acls` on it. For the
command help type:

    samba-add-share -h

### `samba-remove-share`

Remove the share configuration from the Samba registry and erase the share
directory with all of its contents. The command takes just one argument:
the share name.

    samba-remove-share myshare1

### `samba-reset-acls`

Reset the ACLs of a shared directory and its contents. If the share was
created by `rsyncd-import-shares`, reset also the Samba share
configuration to NS8 defaults. For the command help type:

    samba-reset-acls -h

During the reset recursive procedure, the share is not accessible.

### `rsyncd-import-shares`

Starts a special Rsync server used by the NS7 migration tool.  It can
resolve user and group names and it supports Posix ACLs. Configuration
parameters are passed with RSYNCD_* environment variables, as defined in
the
[core/rsync](https://github.com/NethServer/ns8-core/blob/main/core/rsync/README.md)
container. Terminate the server by connecting to the `terminate` Rsync
module. When Rsync completes successfully, the command expects to read
shares metadata from standard input in TSV format to load them into the
Samba configuration registry.

### `validate-demote`

This command checks if the local DC is assigned some FSMO role. Run this
check before decommissioning the DC. Exit-code `2` means some FSMO role is
assigned to the DC.

### `recycle`

This script manages the retention policy of deleted files stored in Samba
recycle bins. It supports three subcommands:

* **`dump_retention`**: Displays current retention settings from the
  registry in JSON format.
* **`set_retention <share> <days>`**: Sets the number of days to retain
  deleted files for a given share.
* **`run_daemon`**: Runs an endless loop that, once per day, deletes files
  from the Recycle bin repository folder of each share whose **change time
  (`ctime`)** exceeds the configured retention period.

## Known startup log messages

At startup, some messages may appear in the log. They might look like
issues, but they are actually harmless and can be safely ignored.

- `RPC fault code DCERPC_NCA_S_OP_RNG_ERROR received from host fs1!` --
  Caused by a race condition during daemon startup

- `ldb: Unable to open tdb '/var/lib/samba/private/secrets.ldb': No such file or directory` -- See bug https://bugzilla.samba.org/show_bug.cgi?id=14657

- `Failed with NT_STATUS_INVALID_SID.` Special SIDs used by some
  authentication methods (e.g., Kerberos) are not properly mapped by
  Winbind.

- `TSIG error with server: tsig verify failure`,
  `dnsupdate_nameupdate_done: Failed DNS update with exit code 10` Another
  race condition. DNS records will be updated correctly when Samba has
  started.

- `smart-multi-line: error opening smart-multi-line.fsm file`, `your
  smart-multi-line.fsm seems to be empty or non-existent`. These messages
  are from `syslog-ng` which expects a file not packaged in Ubuntu 24.04.2
  LTS (Noble Numbat).
