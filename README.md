Welcome to RENKEI-VPE
=====================

RENKEI-VPE is a virtual machine management system on a distributed environment.
It manages geographically distributed servers with kvm virtualization and gfarm client supports, invokes VMs on them and manages life cycle of the VMs.

RENKEI-VPE is deployed and operated in High Performance Computing Infrastructure (HPCI) to support HPC researches.

[HPCI Advanced Software Development Environment](http://hpci-ae.r.gsic.titech.ac.jp/)


Supported Platforms
-------------------

RENKEI-VPE runs on CentOS 6.x (i386/amd64) with the following software.

* Ruby 1.8.7 (1.9.x is NOT tested yet)
  * ruby-progressbar (>= 1.0.2)
  * nokogiri (>= 1.5.0)
  * sqlite3 (>= 1.3.5)
* OpenNebula 2.2.1
* Gfarm 2.x

RENKEI-VPE can control VMs running the following OS.

* CentOS 5.x and 6.x
* Scientific Linux 5.x and 6.x

Servers which run VMs using RENKEI-VPE can be any Linux machines.
We have tested on the following servers as resources of RENKEI-VPE.

* CentOS 5.x and 6.x
* Gfarm 2.x


Install
-------

RENKEI-VPE Installation manual and management manual are written in Japanese.
If you want the manual, contact me.


License
-------

RENKEI-VPE is released under [Apache License Version 2.0](http://www.apache.org/licenses/LICENSE-2.0).


Related Links
-------------

* [HPCI Advanced Software Development Environment](http://hpci-ae.r.gsic.titech.ac.jp/en/)
* [High Performance Computing Ifrastructure Consortium](http://hpci-c.jp)
* [REsources liNKage for E-scIence (RENKEI)](http://www.e-sciren.org/index-e.html)

* [![Code Climate](https://codeclimate.com/badge.png)](https://codeclimate.com/github/stakizawa/renkei-vpe)

