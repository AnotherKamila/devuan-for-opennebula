Makefile to create a Devuan VM image compatible with OpenNebula
===============================================================

Tested with OpenNebula 5.2.1.

You need sufficiently new tools for this -- e.g. Debian stable (as of June 2017) has a version of cfdisk that causes trouble.
Packages from **up-to-date Ubuntu 16.04** should work.

First install the required packages:
`sudo apt-get install make qemu-utils libguestfs-tools`

The Makefile uses sudo where root is required, so it must be configured for your user.

Also note that:

- any automount must be disabled, otherwise it could interfere
- don't run VirtualBox at the same time -- the kvm device is apparently exclusive access
