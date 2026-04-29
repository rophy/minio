#!/bin/bash
# Network functions compatible with Bitnami chart expectations

. /opt/bitnami/scripts/liblog.sh
. /opt/bitnami/scripts/libvalidations.sh

dns_lookup() {
	local host="${1:?host is missing}"
	local ip_version="${2:-}"
	getent "ahosts${ip_version}" "$host" | awk '/STREAM/ {print $1 }' | head -n 1
}

get_machine_ip() {
	local hostname
	hostname="$(hostname)"
	local -a ip_addresses
	read -r -a ip_addresses <<<"$(dns_lookup "$hostname" | xargs echo)"
	if [[ ${#ip_addresses[@]} -gt 1 ]]; then
		warn "Found more than one IP address associated to hostname ${hostname}: ${ip_addresses[*]}, will use ${ip_addresses[0]}"
	elif [[ ${#ip_addresses[@]} -lt 1 ]]; then
		error "Could not find any IP address associated to hostname ${hostname}"
		exit 1
	fi
	echo "${ip_addresses[0]}"
}

parse_uri() {
	local uri="${1:?uri is missing}"
	local component="${2:?component is missing}"
	local -r URI_REGEX='^(([^:/?#]+):)?(//((([^@/?#]+)@)?([^:/?#]+)(:([0-9]+))?))?(/([^?#]*))?(\?([^#]*))?(#(.*))?'
	local index=0
	case "$component" in
	scheme) index=2 ;;
	authority) index=4 ;;
	userinfo) index=6 ;;
	host) index=7 ;;
	port) index=9 ;;
	path) index=10 ;;
	query) index=13 ;;
	fragment) index=14 ;;
	*)
		stderr_print "unrecognized component $component"
		return 1
		;;
	esac
	[[ $uri =~ $URI_REGEX ]] && echo "${BASH_REMATCH[${index}]}"
}
