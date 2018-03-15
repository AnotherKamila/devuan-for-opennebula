# set these according to the path and filename at the mirror (files.devuan.org)
DEVUAN_CODENAME=ascii
DEVUAN_IMAGE=devuan_ascii_2.0.0-beta_amd64_qemu
MIRROR_BASEURL=https://files.devuan.org/devuan_ascii_beta/virtual

# check https://github.com/OpenNebula/addon-context-linux/releases for available versions, we want the .deb
ONECONTEXT_VERSION=5.4.2-1
ONECONTEXT_BASEURL=https://github.com/OpenNebula/addon-context-linux/releases/download/v5.4.2

.PHONY: help clean clean_mounts

##### Make this makefile awesome

help: # https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html <3
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "%-10s %s\n", $$1, $$2}'

##### Targets for humans

download_files: $(DEVUAN_IMAGE).qcow2 packages/one-context_$(ONECONTEXT_VERSION).deb  ## Download the needed files

qcow2: $(DEVUAN_IMAGE)_opennebula.qcow2  ## Make a qcow2-formatted opennebula image

raw: $(DEVUAN_IMAGE)_opennebula.raw  ## Make a raw opennebula image

##### Targets that do stuff

## downloading and such

$(DEVUAN_IMAGE).qcow2:
	wget $(MIRROR_BASEURL)/$(DEVUAN_IMAGE).qcow2
	rm -f SHA256SUMS
	wget $(MIRROR_BASEURL)/SHA256SUMS
	grep $@ SHA256SUMS | sha256sum -c || mv $@ $@.BADSUM

one-context_$(ONECONTEXT_VERSION).deb:
	wget $(ONECONTEXT_BASEURL)/one-context_$(ONECONTEXT_VERSION).deb
	touch $@

## making the image

$(DEVUAN_IMAGE)_opennebula.raw: $(DEVUAN_IMAGE).qcow2 one-context_$(ONECONTEXT_VERSION).deb
	dd if=/dev/zero of=WORK-$@ bs=4M count=750
	mkdir -p /tmp/mnt/devuan_src /tmp/mnt/devuan

	@echo Need root privileges for loop-mounting the images

	# 1. loop mount original image
	sudo modprobe nbd max_part=63
	sudo qemu-nbd --connect=/dev/nbd0 $<

	# 2. loop new image
	DEV=$$(sudo losetup -f --show WORK-$@); echo '2048' | sudo sfdisk $$DEV; sudo losetup -d $$DEV
	DEV=$$(sudo losetup -P -f --show WORK-$@); sudo mkfs.ext4 -L $(DEVUAN_IMAGE) $${DEV}p1; sudo mount $${DEV}p1 /tmp/mnt/devuan

	# 3. copy from orig to mine
	sudo mount /dev/nbd0p1 /tmp/mnt/devuan_src
	sudo rsync -aHS /tmp/mnt/devuan_src/ /tmp/mnt/devuan/
	sudo umount /tmp/mnt/devuan_src

	sudo mount --bind /dev  /tmp/mnt/devuan/dev
	sudo mount --bind /sys  /tmp/mnt/devuan/sys
	sudo mount --bind /proc /tmp/mnt/devuan/proc
	sudo cp /tmp/mnt/devuan/etc/resolv.conf /tmp/mnt/devuan/etc/resolv.conf.orig
	sudo cp /etc/resolv.conf /tmp/mnt/devuan/etc/resolv.conf

	# dependencies are broken, so...
	echo "deb http://packages.devuan.org/merged $(DEVUAN_CODENAME)-backports main" | sudo tee /tmp/mnt/devuan/etc/apt/sources.list.d/devuan-backports.list >/dev/null
	sudo chroot /tmp/mnt/devuan apt-get update
	sudo chroot /tmp/mnt/devuan apt-get -t $(DEVUAN_CODENAME)-backports install -y cloud-utils
	sudo rm /tmp/mnt/devuan/etc/apt/sources.list.d/devuan-backports.list

	sudo chroot /tmp/mnt/devuan apt-get update
	sudo chroot /tmp/mnt/devuan apt-get upgrade -y

	cp one-context_$(ONECONTEXT_VERSION).deb /tmp/mnt/devuan/tmp
	sudo chroot /tmp/mnt/devuan dpkg -i /tmp/one-context_$(ONECONTEXT_VERSION).deb || true  # will fix below
	sudo chroot /tmp/mnt/devuan apt-get install -f -y  # fix broken package -- install onecontext dependencies and onecontext
	sudo chroot /tmp/mnt/devuan apt-get upgrade -y

	sudo chroot /tmp/mnt/devuan passwd -d root

	sudo cp /tmp/mnt/devuan/etc/resolv.conf.orig /tmp/mnt/devuan/etc/resolv.conf
	sync
	sleep 2
	sudo umount -l /tmp/mnt/devuan/proc
	sudo umount -l /tmp/mnt/devuan/sys
	sudo umount -l /tmp/mnt/devuan/dev
	sudo umount -l /tmp/mnt/devuan

	sync
	sleep 2

	sudo virt-customize -v --format raw --add WORK-$@ --no-network --run-command 'update-grub; grub-install `ls -1 /dev/?da | head -n1`'  # hda, sda, vda, who am I to know

	# 4. clean up
	sudo qemu-nbd --disconnect /dev/nbd0
	DEV=$$(losetup -a | grep $(DEVUAN_IMAGE) | cut -d: -f1); sudo losetup -d $$DEV
	mv WORK-$@ $@

$(DEVUAN_IMAGE)_opennebula.qcow2: $(DEVUAN_IMAGE)_opennebula.raw
	qemu-img convert $< $@

##### Helper targets

clean:  ## Removes files listed in ./.gitignore
	rm -f $$(cat ./.gitignore | grep -v '^#')

clean_mounts:  ## Unmounts everything. Run this if a previous run failed.
	sudo umount -l /tmp/mnt/devuan_src || true
	sudo umount -l /tmp/mnt/devuan/proc || true
	sudo umount -l /tmp/mnt/devuan/sys || true
	sudo umount -l /tmp/mnt/devuan/dev || true
	sudo umount -l /tmp/mnt/devuan || true
	sudo qemu-nbd --disconnect /dev/nbd0 || true
	DEV=$$(losetup -a | grep $(DEVUAN_IMAGE) | cut -d: -f1); sudo losetup -d $$DEV || true
