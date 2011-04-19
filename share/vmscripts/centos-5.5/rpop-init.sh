#!/bin/bash
#
# Init file for OpenNebula VM Image
#
# chkconfig: 2345 9 99
# description: OpenNebula configuration

RETVAL=0

start()
{
	mount -t iso9660 /dev/hdc /mnt
	if [ -f /mnt/context.sh ]; then
       		/mnt/init.rb
	fi
	umount /mnt
}

stop()
{
	:
}

case "$1" in
	start)
		start
		;;
	stop)
		stop
		;;
	restart)
		stop
		start
		;;
	status)
		echo "Not implemented yet"
		;;
	*)
		echo $"Usage: $0 {start|stop|restart|status}"
		RETVAL=1
esac
exit $RETVAL
