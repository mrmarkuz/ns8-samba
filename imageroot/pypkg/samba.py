#
# Copyright (C) 2022 Nethesis S.r.l.
# http://www.nethesis.it - nethserver@nethesis.it
#
# This script is part of NethServer.
#
# NethServer is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License,
# or any later version.
#
# NethServer is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with NethServer.  If not, see COPYING.
#

import ipaddress as ipm
import subprocess
import socket
import json
import dns.resolver
import sys
import agent
import os
import cluster.userdomains
import yaml
import configparser

class SambaException(Exception):
    pass

class IpNotPrivate(SambaException):
    pass

class IpNotAvailable(SambaException):
    pass

class IpBindError(SambaException):
    def __init__(self, ipaddr, message):
        self.ipaddr = ipaddr
        self.message = message
        super().__init__(self.message)

def ipaddress_check(ipaddress):
    """Run all checks together"""
    ipaddress_check_isprivate(ipaddress)
    ipaddress_check_isavailable(ipaddress)
    ipaddress_check_hasfreeports(ipaddress)
    return True

def ipaddress_check_isprivate(ipaddress):
    """The IP address must be in a private network class"""
    addr = ipm.ip_address(ipaddress)
    # See Python docs: https://docs.python.org/3.9/library/ipaddress.html#ip-addresses
    if not addr.is_private or addr.is_unspecified or addr.is_reserved or addr.is_loopback or addr.is_link_local:
        raise IpNotPrivate()

    return True

def ipaddress_check_isavailable(ipaddress):
    """The IP address is available and it is possible to bind a random port on it"""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sk:
                sk.bind((ipaddress, 0))
    except Exception as ex:
        raise IpNotAvailable(f"Address {ipaddress} bind failed: {ex}") from ex

    return True

def ipaddress_check_hasfreeports(ipaddress):
    """TCP ports for DC services are free on the given IP address"""
    for tcp_port in [53, 88, 636, 464, 445, 3268, 3269, 389, 135, 139]:
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sk:
                sk.bind((ipaddress, tcp_port))
        except Exception as ex:
            raise IpBindError(ipaddress, f"Address {ipaddress}:{tcp_port} bind failed: {ex}") from ex

    return True

def ipaddress_list(skip_wg0=False, only_wg0=False):
    proc = subprocess.run(["ip", "-j", "-4", "address", "show"], text=True, capture_output=True)
    try:
        joutput = json.loads(proc.stdout)
    except json.JSONDecodeError:
        return []

    ipaddresses = []
    for iface in joutput:
        try:
            # skip wg0, as required by arguments
            if iface["ifname"] == "wg0" and skip_wg0:
                continue
            # skip non-wg0 interfaces, as required by arguments
            if iface["ifname"] != "wg0" and only_wg0:
                continue
            # skip interface without bcast address; wg0 is handled specially
            if iface["ifname"] != "wg0" and not 'BROADCAST' in iface["flags"]:
                continue
            # skip CNI interfaces
            if iface["ifname"].startswith('cni-'):
                continue
        except KeyError:
            pass

        ifip_list = [] # this list collects private ip addresses for iface
        for ainfo in iface['addr_info']:
            addr = ipm.ip_address(ainfo['local'])
            if addr.is_private and not (addr.is_unspecified or addr.is_reserved or addr.is_loopback or addr.is_link_local):
                altnames = ""
                if 'altnames' in iface:
                    altnames = f" ({', '.join(iface['altnames'])})"
                ifip_list.append({
                    "ipaddress": ainfo['local'],
                    "label": iface['ifname'] + altnames
                })
            else:
                # If the interface has at least a non-private
                # address, ignore it completely
                break
        else:
            # If the loop completes without breaking, add collected
            # ip addresses to the response list
            ipaddresses += ifip_list
    return ipaddresses

def validate_hostname(hostname, realm, nameservers=[]):
    rsv = dns.resolver.Resolver(configure=False)
    rsv.nameservers.extend(nameservers)
    try:
        resolve_ret = rsv.resolve(realm)
        print("DNS nameserver", resolve_ret.nameserver, file=sys.stderr)
        print("DNS authority", resolve_ret.response.authority, file=sys.stderr)
        print("Domain", resolve_ret.rrset.to_text(), file=sys.stderr)
    except dns.resolver.NoAnswer:
        json.dump([{"field": "realm", "parameter": "realm", "value": realm, "error": "realm_dc_avail_check_failed"}], fp=sys.stdout)
        agent.set_status('validation-failed')
        sys.exit(6)
    except dns.exception.Timeout:
        json.dump([{"field": "realm", "parameter": "realm", "value": realm, "error": "realm_dc_reachable_check_failed"}], fp=sys.stdout)
        agent.set_status('validation-failed')
        sys.exit(7)

    #
    # Check if the hostname is already registered in the DNS
    #
    try:
        hostname_resolve_ret = rsv.resolve(hostname + '.' + realm)
        print(agent.SD_ERR + f"DC hostname {hostname} is already in DNS!", hostname_resolve_ret.rrset.to_text(), file=sys.stderr)
        json.dump([{"field": "hostname", "parameter": "hostname", "value": hostname, "error": "hostname_check_failed"}], fp=sys.stdout)
        agent.set_status('validation-failed')
        sys.exit(11)
    except dns.resolver.NXDOMAIN:
        pass

def validate_ipaddress(ipaddress):
    try:
        ipaddress_check(ipaddress)
    except IpNotPrivate:
        agent.set_status('validation-failed')
        json.dump([{"field":"ipaddress","parameter":"ipaddress","value": ipaddress,"error":"ipaddress_private_check_failed"}], fp=sys.stdout)
        sys.exit(2)
    except IpNotAvailable:
        agent.set_status('validation-failed')
        json.dump([{"field":"ipaddress","parameter":"ipaddress","value": ipaddress,"error":"ipaddress_avail_check_failed"}], fp=sys.stdout)
        sys.exit(3)
    except IpBindError as ex:
        print(ex, file=sys.stderr)
        agent.set_status('validation-failed')
        json.dump([{"field":"ipaddress","parameter":"ipaddress","value": ex.ipaddr,"error":"ipaddress_bind_check_failed"}], fp=sys.stdout)
        sys.exit(4)

def push_vpn_routes():
    node_id = int(os.environ['NODE_ID'])
    rdb = agent.redis_connect()
    oip_address = ipm.ip_address(os.environ['IPADDRESS'])
    ocluster_network = ipm.ip_network(rdb.get('cluster/network'), strict=False)
    if not oip_address in ocluster_network:
        agent.tasks.run(
            agent_id='cluster',
            action='update-routes',
            data={
                'add': [{
                    "ip_address": os.environ['IPADDRESS'],
                    "node_id": node_id,
                }],
            },
            extra={"isNotificationHidden": True},
        )

def get_joinaddress():
    kdomain = os.getenv('DOMAIN', os.environ['REALM'].lower())

    rdb = agent.redis_connect()
    domains = cluster.userdomains.get_internal_domains(rdb)

    if not kdomain in domains:
        raise SambaException(f'Realm "{kdomain}" not found')

    for provider in domains[kdomain]['providers']:
        if provider['id'] != os.environ["MODULE_ID"]:
            break # DC found. Stop searching.
    else:
        # DC not found: error!
        raise SambaException(f'DC for "{kdomain}" not found')

    return provider['host']

def configure_samba_audit(sharename, enable_audit=True, log_failed_events=False):
    podman_exec = ["podman", "exec", "samba-dc"]
    setparm_cmd = podman_exec + ["net", "conf", "setparm", sharename]
    delparm_cmd = podman_exec + ["net", "conf", "delparm", sharename]
    enabled_success_operations = os.getenv("SAMBA_AUDIT_SUCCESS", "create_file unlinkat renameat mkdirat fsetxattr")
    enabled_failure_operations = os.getenv("SAMBA_AUDIT_FAILURE", "create_file unlinkat renameat mkdirat fsetxattr")
    set_audit_cmd = delparm_cmd + ["full_audit:success"]
    set_logfailed_cmd = delparm_cmd + ["full_audit:failure"]
    if enable_audit:
        set_audit_cmd = setparm_cmd + ["full_audit:success", enabled_success_operations]
        if log_failed_events:
            set_logfailed_cmd = setparm_cmd + ["full_audit:failure", enabled_failure_operations]
    agent.run_helper(*set_audit_cmd, stderr=subprocess.DEVNULL)
    agent.run_helper(*set_logfailed_cmd, stderr=subprocess.DEVNULL)

def provision_metrics():
    count_enable_audit = 0
    # Search for enabled audit shares
    podman_exec = ["podman", "exec", "samba-dc"]
    ocfg = configparser.ConfigParser(delimiters=("="))
    with subprocess.Popen(podman_exec + ["net", "conf", "list"], stdout=subprocess.PIPE, text=True) as hconf:
        try:
            ocfg.read_file(hconf.stdout, 'samba-registry-conf')
        except Exception as ex:
            print(agent.SD_ERR + "Share configuration parse error", ex, file=sys.stderr)

    psharenames = subprocess.run(podman_exec + ["net", "conf", "listshares"], stdout=subprocess.PIPE, text=True)
    for share_name in filter(None, psharenames.stdout.split("\n")):
        if not share_name in ocfg:
            continue
        # Calculate audit settings
        full_audit_success = ocfg[share_name].get("full_audit:success", "none")
        full_audit_failure = ocfg[share_name].get("full_audit:failure", "none")
        if full_audit_success != "none" or full_audit_failure != "none":
            count_enable_audit += 1

    # Set metrics configuration and publish the events
    module_id = os.environ['MODULE_ID']
    agent_id = os.environ['AGENT_ID']
    rdb = agent.redis_connect(privileged=True)
    trx = rdb.pipeline()
    if count_enable_audit > 0:
        tdb = agent.read_envfile("timescaledb.env")
        # Provision the datasource
        ds_name = f"SambaAudit {os.environ['HOSTNAME']}"
        ui_name = rdb.get(f"module/{module_id}/ui_name")
        if ui_name is not None:
            ds_name += f" ({ui_name})"
        else:
            ds_name += f" ({module_id})"
        datasource_dict = {
            "apiVersion": 1,
            "datasources": [
                {
                    "name": ds_name,
                    "type": "postgres",
                    "url": f"{os.environ['IPADDRESS']}:15432",
                    "user": "samba_audit",
                    "secureJsonData": {
                        "password": tdb.get("SAMBA_AUDIT_PASSWORD")
                    },
                    "jsonData": {
                        "database": "samba_audit",
                        "sslmode": "disable",
                        "maxOpenConns": 100,
                        "maxIdleConns": 100,
                        "maxIdleConnsAuto": True,
                        "connMaxLifetime": 14400,
                        "postgresVersion": 17000,
                        "timescaledb": True
                    }
                }
            ]
        }
        # Set the datasource in Redis
        trx.hset(f"module/{module_id}/metrics_datasources", "samba_audit", yaml.dump(datasource_dict))

        # List of dashboard files and their corresponding Redis keys
        for dashboard_key in ["samba_audit_statistics", "samba_audit_search"]:
            with open(f"../etc/grafana/{dashboard_key}.json", "r") as f:
                dashboard_content = f.read()
            trx.hset(f"module/{module_id}/metrics_dashboards", dashboard_key, dashboard_content)
    else:
        print(agent.SD_ERR + "No Samba audit share found, removing datasource and dashboard", file=sys.stderr)
        # Cleanup the datasource and dashboard
        trx.hdel(f"module/{module_id}/metrics_datasources", "samba_audit")
        trx.hdel(f"module/{module_id}/metrics_dashboards", "samba_audit")

    # Always publish the datasource and dashboard change events
    # to reload the configuration and cleanup removed items
    trx.publish(f"{agent_id}/event/metrics-datasource-changed", "{}")
    trx.publish(f"{agent_id}/event/metrics-dashboard-changed", "{}")
    trx.execute()
