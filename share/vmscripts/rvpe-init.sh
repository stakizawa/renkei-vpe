#!/bin/bash
#
# Init file for RenkeiVPE VM Image
#
# chkconfig: 2345 9 99
# description: RenkeiVPE configuration

RETVAL=0

lib_dir=/var/lib/rvpe_init
new_context=/mnt/context.sh
old_context=$lib_dir/context.sh

_init()
{
	mkdir -p $lib_dir
	/mnt/init.rb $new_context $lib_dir
	/bin/cp $new_context $old_context
}

_init_after_erase()
{
	rm -rf $lib_dir
	_init
}

_finalize()
{
	/mnt/final.rb $new_context $lib_dir
}

_mount_cdrom()
{
	# check redhat version
	major_v=`cat /etc/redhat-release | sed -e 's/^.*\([0-9]\)\.[0-9].*$/\1/'`
	if [ "$major_v" == "6" ]; then
		mount -t iso9660 -o ro /dev/sr0 /mnt
	elif [ "$major_v" == "5" ]; then
		mount -t iso9660 /dev/hdc /mnt
	else
		echo "Unsupported version of CentOS."
		exit 1
	fi
}


start()
{
	_mount_cdrom
	if [ -f $new_context ]; then
		if [ ! -f $old_context ]
		then
			_init
		else
			if ! diff $new_context $old_context >/dev/null; then
				_init_after_erase
			fi
		fi
	fi
	umount /mnt
	touch /var/lock/subsys/rvpe-init
}

stop()
{
	_mount_cdrom
	_finalize
	umount /mnt
	rm -f /var/lock/subsys/rvpe-init
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
