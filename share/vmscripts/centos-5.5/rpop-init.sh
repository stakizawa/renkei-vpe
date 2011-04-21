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

start()
{
	mount -t iso9660 /dev/hdc /mnt
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
