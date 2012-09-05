****************************************
Setup an OS image to use in RENKEI-VPE
****************************************

1. install rvpe-init.sh to system daemon directory, such as /etc/init.d

     # cp rvpe-init.sh /etc/init.d/rvpe-init

2. setup rvpe-init to run on boot

     When CentOS
     # chkconfig rvpe-init --add

3. modify /etc/fstab to mount swap partition

     # vi /etc/fstab
         /dev/hdd       swap     swap    defaults        0 0

4. install wrapper for shutdown commands in 'command_wrapper' directory.

     # mkdir -p /usr/rvpe/bin
     # cp halt /usr/rvpe/bin
     # cp poweroff /usr/rvpe/bin
     # cp shutdown /usr/rvpe/bin

5. create environment files

     # vi /etc/profile.d/renkei-vpe.csh
         setenv PATH /usr/rvpe/bin:$PATH

     # vi /etc/profile.d/renkei-vpe.sh
         export PATH=/usr/rvpe/bin:$PATH
