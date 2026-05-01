#!/bin/bash
# Filesystem functions compatible with Bitnami chart expectations

. /opt/bitnami/scripts/liblog.sh

owned_by() {
	local path="${1:?path is missing}"
	local owner="${2:?owner is missing}"
	local group="${3:-}"
	if [[ -n $group ]]; then
		chown "$owner":"$group" "$path"
	else
		chown "$owner":"$owner" "$path"
	fi
}

ensure_dir_exists() {
	local dir="${1:?directory is missing}"
	local owner_user="${2:-}"
	local owner_group="${3:-}"
	[ -d "${dir}" ] || mkdir -p "${dir}"
	if [[ -n $owner_user ]]; then
		owned_by "$dir" "$owner_user" "$owner_group"
	fi
}

is_dir_empty() {
	local -r path="${1:?missing directory}"
	local -r dir="$(realpath "$path")"
	if [[ ! -e $dir ]] || [[ -z "$(ls -A "$dir")" ]]; then
		true
	else
		false
	fi
}

configure_permissions_ownership() {
	local -r paths="${1:?paths is missing}"
	local dir_mode="" file_mode="" user="" group=""
	shift 1
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-f | --file-mode)
			shift
			file_mode="${1:?missing mode for files}"
			;;
		-d | --dir-mode)
			shift
			dir_mode="${1:?missing mode for directories}"
			;;
		-u | --user)
			shift
			user="${1:?missing user}"
			;;
		-g | --group)
			shift
			group="${1:?missing group}"
			;;
		*)
			echo "Invalid command line flag $1" >&2
			return 1
			;;
		esac
		shift
	done
	read -r -a filepaths <<<"$paths"
	for p in "${filepaths[@]}"; do
		if [[ -e $p ]]; then
			[[ -n $dir_mode ]] && find -L "$p" -type d ! -perm "$dir_mode" -print0 | xargs -r -0 chmod "$dir_mode"
			[[ -n $file_mode ]] && find -L "$p" -type f ! -perm "$file_mode" -print0 | xargs -r -0 chmod "$file_mode"
			if [[ -n $user ]] && [[ -n $group ]]; then
				find -L "$p" -print0 | xargs -r -0 chown "${user}:${group}"
			elif [[ -n $user ]]; then
				find -L "$p" -print0 | xargs -r -0 chown "${user}"
			elif [[ -n $group ]]; then
				find -L "$p" -print0 | xargs -r -0 chgrp "${group}"
			fi
		fi
	done
}
