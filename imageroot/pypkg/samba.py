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
