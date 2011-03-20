***********************************
Instration on OS image for VMs
***********************************

1. install rpop-init.sh to system daemon directory, such as /etc/init.d

     # cp rpop-init.sh /etc/init.d/rpop-init

2. setup rpop-init to run on boot

     When CentOS
     # chkconfig rpop-init --add

3. modify /etc/fstab to mount swap partition

     # vi /etc/fstab
         /dev/hdd       swap     swap    defaults        0 0


***********************************
Instration on OS image for VMs
***********************************

Don't forget to put init.rb in a cd-iso image.
It is called in 'rpop-init.sh' script to configure VM.
