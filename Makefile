DEVUAN_VERSION=jessie_1.0.0_amd64
ONECONTEXT_VERSION=5.0.3

.PHONY: help clean clean_mounts

##### Make this makefile awesome

help: # https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html <3
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "%-10s %s\n", $$1, $$2}'

##### Targets for humans

download_files: devuan_$(DEVUAN_VERSION)_virtual.qcow2 packages/one-context_$(ONECONTEXT_VERSION).deb  ## Download the needed files

qcow2: devuan_$(DEVUAN_VERSION)_opennebula.qcow2  ## Make a qcow2-formatted opennebula image

raw: devuan_$(DEVUAN_VERSION)_opennebula.raw  ## Make a raw opennebula image

##### Targets that do stuff

## downloading and such

devuan_$(DEVUAN_VERSION)_virtual.qcow2.xz:
	wget https://files.devuan.org/devuan_jessie/virtual/devuan_jessie_1.0.0_amd64_virtual.qcow2.xz
	wget https://files.devuan.org/devuan_jessie/virtual/SHA256SUMS
	grep $@ SHA256SUMS | sha256sum -c || mv $@ $@.BADSUM

devuan_$(DEVUAN_VERSION)_virtual.qcow2: devuan_$(DEVUAN_VERSION)_virtual.qcow2.xz
	unxz --keep $<

one-context_$(ONECONTEXT_VERSION).deb:
	wget https://github.com/OpenNebula/addon-context-linux/releases/download/v$(ONECONTEXT_VERSION)/one-context_$(ONECONTEXT_VERSION).deb
	touch $@

## making the image

devuan_$(DEVUAN_VERSION)_opennebula.raw: devuan_$(DEVUAN_VERSION)_virtual.qcow2 one-context_$(ONECONTEXT_VERSION).deb
	dd if=/dev/zero of=WORK-$@ bs=4M count=750
	mkdir -p /tmp/mnt/devuan_src /tmp/mnt/devuan

	@echo Neet root privileges for loop-mounting the images

	# 1. loop mount original image
	sudo modprobe nbd max_part=63
	sudo qemu-nbd --connect=/dev/nbd0 $<

	# 2. loop new image
	DEV=$$(sudo losetup -f --show WORK-$@); echo ';' | sudo sfdisk $$DEV; sudo losetup -d $$DEV
	DEV=$$(sudo losetup -P -f --show WORK-$@); sudo mkfs.ext4 -L $(DEVUAN_VERSION) $${DEV}p1; sudo mount $${DEV}p1 /tmp/mnt/devuan

	# 3. copy from orig to mine
	sudo mount /dev/nbd0p1 /tmp/mnt/devuan_src
	sudo rsync -aHS /tmp/mnt/devuan_src/ /tmp/mnt/devuan/
	sudo umount /tmp/mnt/devuan_src

	sudo mount --bind /dev  /tmp/mnt/devuan/dev
	sudo mount --bind /sys  /tmp/mnt/devuan/sys
	sudo mount --bind /proc /tmp/mnt/devuan/proc
	sudo mkdir -p /tmp/mnt/devuan/run/resolvconf
	sudo cp /tmp/mnt/devuan/etc/resolv.conf /tmp/mnt/devuan/etc/resolv.conf.orig
	sudo cp /etc/resolv.conf /tmp/mnt/devuan/etc/resolv.conf

	DEV=$$(losetup -a | grep $(DEVUAN_VERSION) | cut -d: -f1 | head -n1); sudo chroot /tmp/mnt/devuan grub-install $$DEV

	cp one-context_$(ONECONTEXT_VERSION).deb /tmp/mnt/devuan/tmp
	sudo chroot /tmp/mnt/devuan dpkg -i /tmp/one-context_$(ONECONTEXT_VERSION).deb

	# dependencies are broken, so...
	echo 'deb http://packages.devuan.org/merged jessie-backports main' | sudo tee /tmp/mnt/devuan/etc/apt/sources.list.d/devuan-backports.list >/dev/null
	sudo chroot /tmp/mnt/devuan apt-get update
	sudo chroot /tmp/mnt/devuan apt-get -t jessie-backports install -y cloud-utils
	sudo rm /tmp/mnt/devuan/etc/apt/sources.list.d/devuan-backports.list
	sudo chroot /tmp/mnt/devuan apt-get update
	sudo chroot /tmp/mnt/devuan apt-get upgrade -y
	sudo chroot /tmp/mnt/devuan apt-get install -y ruby

	sudo chroot /tmp/mnt/devuan passwd -d root

	sudo cp /tmp/mnt/devuan/etc/resolv.conf.orig /tmp/mnt/devuan/etc/resolv.conf
	sync
	sleep 2
	sync
	sudo umount /tmp/mnt/devuan/proc
	sudo umount /tmp/mnt/devuan

	# 4. clean up
	sudo qemu-nbd --disconnect /dev/nbd0
	DEV=$$(losetup -a | grep $(DEVUAN_VERSION) | cut -d: -f1); sudo losetup -d $$DEV
	mv WORK-$@ $@

clean_mounts:
	sudo umount -l /tmp/mnt/devuan_src || true
	sudo umount -l /tmp/mnt/devuan/proc || true
	sudo umount -l /tmp/mnt/devuan/sys || true
	sudo umount -l /tmp/mnt/devuan/dev || true
	sudo umount -l /tmp/mnt/devuan || true
	sudo qemu-nbd --disconnect /dev/nbd0 || true
	DEV=$$(losetup -a | grep $(DEVUAN_VERSION) | cut -d: -f1); sudo losetup -d $$DEV || true

devuan_$(DEVUAN_VERSION)_opennebula.qcow2: devuan_$(DEVUAN_VERSION)_opennebula.raw
	qemu-img convert $< $@

##### Helper targets

clean:  ## Removes files listed in ./.gitignore
	rm -f $$(cat ./.gitignore | grep -v '^#')
