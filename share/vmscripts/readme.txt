***********************************
Instration on OS image for VMs
***********************************

1. install rvpe-init.sh to system daemon directory, such as /etc/init.d

     # cp rvpe-init.sh /etc/init.d/rvpe-init

2. setup rvpe-init to run on boot

     When CentOS
     # chkconfig rvpe-init --add

3. modify /etc/fstab to mount swap partition

     # vi /etc/fstab
         /dev/hdd       swap     swap    defaults        0 0


***********************************
Instration on OS image for VMs
***********************************

Don't forget to put init.rb in a cd-iso image.
It is called in 'rvpe-init.sh' script to configure VM.
