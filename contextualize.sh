mount LABEL=PACKAGES /mnt
dpkg -i  /mnt/one-context*deb
# apt-get install -y ruby  # only needed for onegate command
# apt-get install -y cloud-utils

# TODO is this needed?
# Unconfigure serial console. OpenNebula does not configure a serial console
# and growpart in initrd tries to write to it. It panics in the first boot
# if it is configured in the kernel parameters.
# sed -i 's/console=ttyS0,115200//' /extlinux.conf
# cat /extlinux.conf
