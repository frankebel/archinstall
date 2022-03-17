#!/bin/sh
printf "Select timezone (Enter for list): "
read -r timezone
region=""
while true; do
	if [ -f "/usr/share/zoneinfo/$timezone" ]; then
		printf "Confirm timezone: %s [y/N] " "$timezone"
		read -r yn
		yn="${yn:-n}"
		case "$yn" in
			[yY]* )
				break
				;;
			* )
				timezone=""
				region=""
				;;
		esac
	elif ! [ "$region" = "" ] && [ -d "/usr/share/zoneinfo/$region" ]; then
		ls "/usr/share/zoneinfo/$region"
		printf "Enter city: "
		read -r city
		timezone="$region/$city"
	else 
		find /usr/share/zoneinfo -maxdepth 1 -type d | awk -F "/" '{print $5}'
		printf "Enter region: "
		read -r region
	fi

done
unset yn
