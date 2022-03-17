#!/bin/sh
case "$(lscpu | grep 'Vendor ID')" in
	*AuthenticAMD )
		printf "AMD\n"
		;;
	*GenuineIntel )
		printf "Intel\n"
		;;
	* )
		printf "no match\n"
		;;
esac
