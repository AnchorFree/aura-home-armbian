#!/bin/bash

# arguments: $RELEASE $LINUXFAMILY $BOARD $BUILD_DESKTOP
#
# This is the image customization script

# NOTE: It is copied to /tmp directory inside the image
# and executed there inside chroot environment
# so don't reference any files that are not already installed

# NOTE: If you want to transfer files between chroot and host
# userpatches/overlay directory on host is bind-mounted to /tmp/overlay in chroot
# The sd card's root path is accessible via $SDCARD variable.

RELEASE=$1
LINUXFAMILY=$2
BOARD=$3
BUILD_DESKTOP=$4

Main() {
	InstallAurahome

	case $RELEASE in
		stretch)
			# your code here
			# InstallOpenMediaVault # uncomment to get an OMV 4 image
			;;
		buster)
			# your code here
			;;
		bullseye)
			# your code here
			;;
		bionic)
			# your code here
			;;
		focal)
			# your code here
			;;
	esac
} # Main

InstallOpenMediaVault() {
	# use this routine to create a Debian based fully functional OpenMediaVault
	# image (OMV 3 on Jessie, OMV 4 with Stretch). Use of mainline kernel highly
	# recommended!
	#
	# Please note that this variant changes Armbian default security
	# policies since you end up with root password 'openmediavault' which
	# you have to change yourself later. SSH login as root has to be enabled
	# through OMV web UI first
	#
	# This routine is based on idea/code courtesy Benny Stark. For fixes,
	# discussion and feature requests please refer to
	# https://forum.armbian.com/index.php?/topic/2644-openmediavault-3x-customize-imagesh/

	echo root:openmediavault | chpasswd
	rm /root/.not_logged_in_yet
	. /etc/default/cpufrequtils
	export LANG=C LC_ALL="en_US.UTF-8"
	export DEBIAN_FRONTEND=noninteractive
	export APT_LISTCHANGES_FRONTEND=none

	case ${RELEASE} in
		jessie)
			OMV_Name="erasmus"
			OMV_EXTRAS_URL="https://github.com/OpenMediaVault-Plugin-Developers/packages/raw/master/openmediavault-omvextrasorg_latest_all3.deb"
			;;
		stretch)
			OMV_Name="arrakis"
			OMV_EXTRAS_URL="https://github.com/OpenMediaVault-Plugin-Developers/packages/raw/master/openmediavault-omvextrasorg_latest_all4.deb"
			;;
	esac

	# Add OMV source.list and Update System
	cat > /etc/apt/sources.list.d/openmediavault.list <<- EOF
	deb https://openmediavault.github.io/packages/ ${OMV_Name} main
	## Uncomment the following line to add software from the proposed repository.
	deb https://openmediavault.github.io/packages/ ${OMV_Name}-proposed main

	## This software is not part of OpenMediaVault, but is offered by third-party
	## developers as a service to OpenMediaVault users.
	# deb https://openmediavault.github.io/packages/ ${OMV_Name} partner
	EOF

	# Add OMV and OMV Plugin developer keys, add Cloudshell 2 repo for XU4
	if [ "${BOARD}" = "odroidxu4" ]; then
		add-apt-repository -y ppa:kyle1117/ppa
		sed -i 's/jessie/xenial/' /etc/apt/sources.list.d/kyle1117-ppa-jessie.list
	fi
	mount --bind /dev/null /proc/mdstat
	apt-get update
	apt-get --yes --force-yes --allow-unauthenticated install openmediavault-keyring
	apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 7AA630A1EDEE7D73
	apt-get update

	# install debconf-utils, postfix and OMV
	HOSTNAME="${BOARD}"
	debconf-set-selections <<< "postfix postfix/mailname string ${HOSTNAME}"
	debconf-set-selections <<< "postfix postfix/main_mailer_type string 'No configuration'"
	apt-get --yes --force-yes --allow-unauthenticated  --fix-missing --no-install-recommends \
		-o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install \
		debconf-utils postfix
	# move newaliases temporarely out of the way (see Ubuntu bug 1531299)
	cp -p /usr/bin/newaliases /usr/bin/newaliases.bak && ln -sf /bin/true /usr/bin/newaliases
	sed -i -e "s/^::1         localhost.*/::1         ${HOSTNAME} localhost ip6-localhost ip6-loopback/" \
		-e "s/^127.0.0.1   localhost.*/127.0.0.1   ${HOSTNAME} localhost/" /etc/hosts
	sed -i -e "s/^mydestination =.*/mydestination = ${HOSTNAME}, localhost.localdomain, localhost/" \
		-e "s/^myhostname =.*/myhostname = ${HOSTNAME}/" /etc/postfix/main.cf
	apt-get --yes --force-yes --allow-unauthenticated  --fix-missing --no-install-recommends \
		-o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install \
		openmediavault

	# install OMV extras, enable folder2ram and tweak some settings
	FILE=$(mktemp)
	wget "$OMV_EXTRAS_URL" -qO $FILE && dpkg -i $FILE

	/usr/sbin/omv-update
	# Install flashmemory plugin and netatalk by default, use nice logo for the latter,
	# tweak some OMV settings
	. /usr/share/openmediavault/scripts/helper-functions
	apt-get -y -q install openmediavault-netatalk openmediavault-flashmemory
	AFP_Options="mimic model = Macmini"
	SMB_Options="min receivefile size = 16384\nwrite cache size = 524288\ngetwd cache = yes\nsocket options = TCP_NODELAY IPTOS_LOWDELAY"
	xmlstarlet ed -L -u "/config/services/afp/extraoptions" -v "$(echo -e "${AFP_Options}")" /etc/openmediavault/config.xml
	xmlstarlet ed -L -u "/config/services/smb/extraoptions" -v "$(echo -e "${SMB_Options}")" /etc/openmediavault/config.xml
	xmlstarlet ed -L -u "/config/services/flashmemory/enable" -v "1" /etc/openmediavault/config.xml
	xmlstarlet ed -L -u "/config/services/ssh/enable" -v "1" /etc/openmediavault/config.xml
	xmlstarlet ed -L -u "/config/services/ssh/permitrootlogin" -v "0" /etc/openmediavault/config.xml
	xmlstarlet ed -L -u "/config/system/time/ntp/enable" -v "1" /etc/openmediavault/config.xml
	xmlstarlet ed -L -u "/config/system/time/timezone" -v "UTC" /etc/openmediavault/config.xml
	xmlstarlet ed -L -u "/config/system/network/dns/hostname" -v "${HOSTNAME}" /etc/openmediavault/config.xml
	xmlstarlet ed -L -u "/config/system/monitoring/perfstats/enable" -v "0" /etc/openmediavault/config.xml
	echo -e "OMV_CPUFREQUTILS_GOVERNOR=${GOVERNOR}" >>/etc/default/openmediavault
	echo -e "OMV_CPUFREQUTILS_MINSPEED=${MIN_SPEED}" >>/etc/default/openmediavault
	echo -e "OMV_CPUFREQUTILS_MAXSPEED=${MAX_SPEED}" >>/etc/default/openmediavault
	for i in netatalk samba flashmemory ssh ntp timezone interfaces cpufrequtils monit collectd rrdcached ; do
		/usr/sbin/omv-mkconf $i
	done
	/sbin/folder2ram -enablesystemd || true
	sed -i 's|-j /var/lib/rrdcached/journal/ ||' /etc/init.d/rrdcached

	# Fix multiple sources entry on ARM with OMV4
	sed -i '/stretch-backports/d' /etc/apt/sources.list

	# rootfs resize to 7.3G max and adding omv-initsystem to firstrun -- q&d but shouldn't matter
	echo 15500000s >/root/.rootfs_resize
	sed -i '/systemctl\ disable\ armbian-firstrun/i \
	mv /usr/bin/newaliases.bak /usr/bin/newaliases \
	export DEBIAN_FRONTEND=noninteractive \
	sleep 3 \
	apt-get install -f -qq python-pip python-setuptools || exit 0 \
	pip install -U tzupdate \
	tzupdate \
	read TZ </etc/timezone \
	/usr/sbin/omv-initsystem \
	xmlstarlet ed -L -u "/config/system/time/timezone" -v "${TZ}" /etc/openmediavault/config.xml \
	/usr/sbin/omv-mkconf timezone \
	lsusb | egrep -q "0b95:1790|0b95:178a|0df6:0072" || sed -i "/ax88179_178a/d" /etc/modules' /usr/lib/armbian/armbian-firstrun
	sed -i '/systemctl\ disable\ armbian-firstrun/a \
	sleep 30 && sync && reboot' /usr/lib/armbian/armbian-firstrun

	# add USB3 Gigabit Ethernet support
	echo -e "r8152\nax88179_178a" >>/etc/modules

	# Special treatment for ODROID-XU4 (and later Amlogic S912, RK3399 and other big.LITTLE
	# based devices). Move all NAS daemons to the big cores. With ODROID-XU4 a lot
	# more tweaks are needed. CS2 repo added, CS1 workaround added, coherent_pool=1M
	# set: https://forum.odroid.com/viewtopic.php?f=146&t=26016&start=200#p197729
	# (latter not necessary any more since we fixed it upstream in Armbian)
	case ${BOARD} in
		odroidxu4)
			HMP_Fix='; taskset -c -p 4-7 $i '
			# Cloudshell stuff (fan, lcd, missing serials on 1st CS2 batch)
			echo "H4sIAKdXHVkCA7WQXWuDMBiFr+eveOe6FcbSrEIH3WihWx0rtVbUFQqCqAkYGhJn
			tF1x/vep+7oebDfh5DmHwJOzUxwzgeNIpRp9zWRegDPznya4VDlWTXXbpS58XJtD
			i7ICmFBFxDmgI6AXSLgsiUop54gnBC40rkoVA9rDG0SHHaBHPQx16GN3Zs/XqxBD
			leVMFNAz6n6zSWlEAIlhEw8p4xTyFtwBkdoJTVIJ+sz3Xa9iZEMFkXk9mQT6cGSQ
			QL+Cr8rJJSmTouuuRzfDtluarm1aLVHksgWmvanm5sbfOmY3JEztWu5tV9bCXn4S
			HB8RIzjoUbGvFvPw/tmr0UMr6bWSBupVrulY2xp9T1bruWnVga7DdAqYFgkuCd3j
			vORUDQgej9HPJxmDDv+3WxblBSuYFH8oiNpHz8XvPIkU9B3JVCJ/awIAAA==" \
			| tr -d '[:blank:]' | base64 --decode | gunzip -c >/usr/local/sbin/cloudshell2-support.sh
			chmod 755 /usr/local/sbin/cloudshell2-support.sh
			apt install -y i2c-tools odroid-cloudshell cloudshell2-fan
			sed -i '/systemctl\ disable\ armbian-firstrun/i \
			lsusb | grep -q -i "05e3:0735" && sed -i "/exit\ 0/i echo 20 > /sys/class/block/sda/queue/max_sectors_kb" /etc/rc.local \
			/usr/sbin/i2cdetect -y 1 | grep -q "60: 60" && /usr/local/sbin/cloudshell2-support.sh' /usr/lib/armbian/armbian-firstrun
			;;
		bananapim3|nanopifire3|nanopct3plus|nanopim3)
			HMP_Fix='; taskset -c -p 4-7 $i '
			;;
		edge*|ficus|firefly-rk3399|nanopct4|nanopim4|nanopineo4|renegade-elite|roc-rk3399-pc|rockpro64|station-p1)
			HMP_Fix='; taskset -c -p 4-5 $i '
			;;
	esac
	echo "* * * * * root for i in \`pgrep \"ftpd|nfsiod|smbd|afpd|cnid\"\` ; do ionice -c1 -p \$i ${HMP_Fix}; done >/dev/null 2>&1" \
		>/etc/cron.d/make_nas_processes_faster
	chmod 600 /etc/cron.d/make_nas_processes_faster

	# add SATA port multiplier hint if appropriate
	[ "${LINUXFAMILY}" = "sunxi" ] && \
		echo -e "#\n# If you want to use a SATA PM add \"ahci_sunxi.enable_pmp=1\" to bootargs above" \
		>>/boot/boot.cmd

	# Filter out some log messages
	echo ':msg, contains, "do ionice -c1" ~' >/etc/rsyslog.d/omv-armbian.conf
	echo ':msg, contains, "action " ~' >>/etc/rsyslog.d/omv-armbian.conf
	echo ':msg, contains, "netsnmp_assert" ~' >>/etc/rsyslog.d/omv-armbian.conf
	echo ':msg, contains, "Failed to initiate sched scan" ~' >>/etc/rsyslog.d/omv-armbian.conf

	# Fix little python bug upstream Debian 9 obviously ignores
	if [ -f /usr/lib/python3.5/weakref.py ]; then
		wget -O /usr/lib/python3.5/weakref.py \
		https://raw.githubusercontent.com/python/cpython/9cd7e17640a49635d1c1f8c2989578a8fc2c1de6/Lib/weakref.py
	fi

	# clean up and force password change on first boot
	umount /proc/mdstat
	chage -d 0 root
} # InstallOpenMediaVault

UnattendedStorageBenchmark() {
	# Function to create Armbian images ready for unattended storage performance testing.
	# Useful to use the same OS image with a bunch of different SD cards or eMMC modules
	# to test for performance differences without wasting too much time.

	rm /root/.not_logged_in_yet

	apt-get -qq install time

	wget -qO /usr/local/bin/sd-card-bench.sh https://raw.githubusercontent.com/ThomasKaiser/sbc-bench/master/sd-card-bench.sh
	chmod 755 /usr/local/bin/sd-card-bench.sh

	sed -i '/^exit\ 0$/i \
	/usr/local/bin/sd-card-bench.sh &' /etc/rc.local
} # UnattendedStorageBenchmark

InstallAdvancedDesktop()
{
	apt-get install -yy transmission libreoffice libreoffice-style-tango meld remmina thunderbird kazam avahi-daemon
	[[ -f /usr/share/doc/avahi-daemon/examples/sftp-ssh.service ]] && cp /usr/share/doc/avahi-daemon/examples/sftp-ssh.service /etc/avahi/services/
	[[ -f /usr/share/doc/avahi-daemon/examples/ssh.service ]] && cp /usr/share/doc/avahi-daemon/examples/ssh.service /etc/avahi/services/
	apt clean
} # InstallAdvancedDesktop

InstallAurahome()
{
	sed -i '/.* \/ ext4/ s/commit=[0-9]*/commit=60/' /etc/fstab

	#echo 'extraargs="maxcpus=2"' >>/boot/armbianEnv.txt
	echo root:pstest123 | chpasswd
	rm /root/.not_logged_in_yet
	touch /root/.no_rootfs_resize

	KEYRING=/usr/share/keyrings/pango-home-archive-keyring.gpg
	cat >/etc/apt/sources.list.d/pango-home.list <<- EOF
	deb [signed-by=$KEYRING] https://deb-packages.home.pango.co/ stable main
	EOF

	base64 --decode >$KEYRING <<- EOF
	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
	EOF

	apt update
	apt install -yyq tmux vim avahi-daemon libnss-mdns dnsmasq iptables-persistent         \
	                 libwebsockets8 libjansson4 libevent-2.1-6 libevent-openssl-2.1-6      \
	                 libevent-pthreads-2.1-6 libbpf4.19 xml2 socat jq avahi-utils nmap     \
	                 python3-nmap ifplugd perseus perseus-led perseus-update uuid-runtime  \
	                 libsystemd-dev

	echo "net.ipv4.ip_forward=1" >>/etc/sysctl.conf
	echo "net.ipv6.conf.all.forwarding=1" >>/etc/sysctl.conf
	echo "net.ipv6.conf.eth0.accept_ra=2" >>/etc/sysctl.conf

	cat >/etc/network/interfaces <<- EOF
	source /etc/network/interfaces.d/*

	auto lo
	iface lo inet loopback

	auto eth0
	allow-hotplug eth0
	iface eth0 inet dhcp
	EOF

	echo "nameserver 8.8.8.8" >/etc/resolv.conf
	echo "aurahome" >/etc/hostname

	cat >/etc/avahi/avahi-daemon.conf <<-EOF
	[server]
	use-ipv4=yes
	use-ipv6=no
	ratelimit-interval-usec=1000000
	ratelimit-burst=1000

	[wide-area]
	enable-wide-area=yes

	[publish]
	publish-hinfo=no
	publish-workstation=no
	EOF

	cat >/etc/default/ifplugd <<-EOF
	INTERFACES="eth0"
	HOTPLUG_INTERFACES=""
	ARGS="-q -f -u0 -d5 -w -I -p"
	SUSPEND_ACTION="stop"
	EOF

	cat >/etc/ifplugd/action.d/ifupdown <<-EOF
	#!/bin/sh
	set -e

	case "\$2" in
	up)
		systemctl restart networking
		#/sbin/ifup \$1
		;;
	down)
		#/sbin/ifdown \$1
		;;
	esac
	EOF

	systemctl enable ifplugd

	systemctl disable NetworkManager
	systemctl enable avahi-daemon

	cat > /etc/overlayroot.local.conf <<- EOF
	overlayroot_cfgdisk="disabled"
	overlayroot="/dev/mmcblk0p2"
	debug=1
	recurse=0
	EOF
} # InstallAurahome

Main "$@"
