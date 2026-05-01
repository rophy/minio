#!/bin/bash
# Validation functions compatible with Bitnami chart expectations

. /opt/bitnami/scripts/liblog.sh

is_int() {
	local -r int="${1:?missing value}"
	[[ $int =~ ^-?[0-9]+ ]]
}

is_boolean_yes() {
	local -r bool="${1:-}"
	shopt -s nocasematch
	[[ $bool == 1 || $bool =~ ^(yes|true)$ ]]
}

is_yes_no_value() {
	local -r bool="${1:-}"
	[[ $bool =~ ^(yes|no)$ ]]
}

is_empty_value() {
	local -r val="${1:-}"
	[[ -z $val ]]
}

validate_port() {
	local unprivileged=0
	while [[ $# -gt 0 ]]; do
		case "$1" in
		-unprivileged) unprivileged=1 ;;
		--)
			shift
			break
			;;
		-*)
			stderr_print "unrecognized flag $1"
			return 1
			;;
		*) break ;;
		esac
		shift
	done
	if [[ $# -eq 0 ]]; then
		stderr_print "missing port argument"
		return 1
	fi
	local value=$1
	if [[ -z $value ]]; then
		echo "the value is empty"
		return 1
	elif ! is_int "$value"; then
		echo "value is not an integer"
		return 2
	elif [[ $value -lt 0 ]]; then
		echo "negative value provided"
		return 2
	elif [[ $value -gt 65535 ]]; then
		echo "requested port is greater than 65535"
		return 2
	elif [[ $unprivileged == 1 && $value -lt 1024 ]]; then
		echo "privileged port requested"
		return 3
	fi
}
