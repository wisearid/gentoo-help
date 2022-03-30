#!/bin/bash
# gendeploy stage1 = stage1 of the Gentoo installation script

headerText="\e[0;35mgen\e[1;35mdeploy \e[0;37m(stage1)\e[0m"

# shellcheck disable=SC2120
headerPrint() {
	clear
	# shellcheck disable=SC2059
	printf "  $headerText                                                       ;-)\n"
	printf "================================================================================\n"
	printf "\n"
}

die() {
	printf "\e[31mError! \e[0m%s\n" "$1"
	[ -f ./.gendeploy.conf ] && [ "$installmode" == "noconf" ] && mv ./.gendeploy.conf ./.old.gendeploy.conf
	exit 2
}

pause() {
	read -n 1 -s -r -p "Press any key to continue..."
}

# detect architecture
[ "$(uname -m)" == "x86_64" ] || die "This script is designed for x86_64 architecture. Please do not attempt to run it anywhere else."

# if no configuration exists, use interactive wizard
noconf() {
	installmode="noconf"

	touch ./.gendeploy.conf

	headerPrint

	printf "Welcome to gendeploy!\n\
\n\
This script will install Gentoo for you.\n\
But, before we can start, I must ask you a few questions.\n\n"

	# UEFI/BIOS check

	if [ -d /sys/firmware/efi ]; then
		printf "I have detected that you are likely on a UEFI system.\n"
		printf "Using UEFI and GPT partitioning scheme!\n"
		echo 'biostype="UEFI"' >> ./.gendeploy.conf
	else
		printf "I have detected that you are likely on a legacy BIOS system.\n"
		printf "Using legacy BIOS and MBR partitioning scheme!\n"
		echo 'biostype="BIOS"' >> ./.gendeploy.conf
	fi

	printf "\n"

	pause

	# network check

	headerPrint

	printf "Let's ping gentoo.org to check if we're online, hm?\n"
	if [ "$(ping -c 3 gentoo.org)" ]; then
		printf "We're online!\n"
		pause
	else
		printf "Oh my, looks like either your internet is down or gentoo.org is down.\n"
		printf "Would you like to run net-setup? (Y/n) "
		read -r yn
		case $yn in
			[Nn]*) die "no gentoo install 4 u ;__;" ;;
			*) net-setup eth0
				printf "Alright, let's try again.\n"
				[ "$(ping -c 3 gentoo.org)" ] || die "That's still not right, I've had enough."
			;;
		esac
	fi

	# ask for drive

	headerPrint

	printf "What drive would you like to install Gentoo on?\n\
For reference, here's lsblk:\n"
	lsblk
	printf "\e[31mWARNING! DO NOT ADD THE /dev/ TO THE BEGINNING!\e[0m\n"
	read -r -p "> " drive
	echo "drive='/dev/$drive'" >> ./.gendeploy.conf

	# set stage3 and profile

	headerPrint

	printf "What stage3 tarball do you prefer?\n\n\
1. Regular OpenRC stage3 (recommended)\n\
2. Hardened OpenRC stage3\n\
3. No-Multilib OpenRC stage3\n\
4. Hardened No-Multilib OpenRC stage3\n\n\
(note: any other option will choose 1)\n\n\
If you don't know what to choose, just press ENTER.\n"
	read -r -p "> " stagetarball

	case $stagetarball in
		"2") stagetype="stage3-amd64-hardened-openrc" ; profile="3"  ;;
		"3") stagetype="stage3-amd64-nomultilib-openrc" ; profile="12" ;;
		"4") stagetype="stage3-amd64-hardened-nomultilib-openrc" ; profile="13"  ;;
		*) stagetype="stage3-amd64-openrc" ; profile="1"  ;;
	esac

	echo "profile=$profile" >> ./.gendeploy.conf

	# thanks to nezbednik for this ;-)
	# this is commented out, it will be moved to the actual installer function
	#IFS="\""
	#read -ra arr <<< $(curl --silent "https://www.gentoo.org/downloads/" | grep --max-count=1 $stagetype)
	#wget "${arr[1]}"

	# ask for make.conf items, such as MAKEOPTS and USE

	headerPrint

	# auto-detect optimal MAKEOPTS value

	ramdivided="$(($(free --gibi --si | awk '/^Mem/ { print $2 }') / 2))"
	if (( "$(nproc)" > "$ramdivided" )); then
		makeopts="-j$ramdivided"
	else
		makeopts="-j$(nproc)"
	fi

	printf "Time to configure make.conf!\n\
First, let's do MAKEOPTS.\n\
Based on your system, the wizard recommends a MAKEOPTS of %s.\n\n" "$makeopts"
	printf "Would you like to change this? (y/N) "
	read -r yn
	case $yn in
		[Yy]*)
			printf "Please enter a new value that DOES NOT start with -j.\n"
			read -r -p "> " makeopts
			echo "makeopts='-j$MAKEOPTS'"
			;;
		*)	printf "Great!\n" ;;
	esac

	export commonflags="-march=native -mtune=native -O2"
	read -r -p "Would you like to use -pipe? (Y/n)" yn
	case $yn in
		[Nn]*) export commonflags="${commonflags}" ;;
		*) export commonflags="${commonflags} -pipe" ;;
	esac

	echo "commonflags='$commonflags'" >> ./.gendeploy.conf

	printf "What USE flags would you like to use?\n"
	read -r -p "> " useflags
	echo "useflags='$useflags'" >> ./.gendeploy.conf
}

# if a configuration file is found, start "lazy" setup
autoinstall() {
	installmode="autoinstall"

	headerPrint

	printf "Welcome to gendeploy!\n\
./.gendeploy.conf file was found, so we're starting the lazy, automated setup.\n\
If this was a mistake (you ^C'd during the initial setup, or it is a leftover),\n\
please press ^C within 5 seconds.\n\n"
	for i in 5 4 3 2 1; do
		printf "%s... " "$i"
		sleep 1
	done
	printf "\n\nAlright, let's start the installation!\n"
}

if [ -f ./.gendeploy.conf ]; then
	autoinstall
else
	noconf
fi
