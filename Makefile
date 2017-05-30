DEVUAN_VERSION=jessie_1.0.0_amd64
ONECONTEXT_VERSION=5.0.3

.PHONY: help clean

##### Make this makefile awesome

help: # https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html <3
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "%-10s %s\n", $$1, $$2}'

##### Targets for humans

download_files: devuan_$(DEVUAN_VERSION)_virtual.qcow2 packages/one-context_$(ONECONTEXT_VERSION).deb  ## Download the needed files

qcow2: devuan_$(DEVUAN_VERSION)_opennebula.qcow2  ## Make a qcow2-formatted opennebula image
	ln -s $< devuan.qcow2

##### Targets that do stuff

devuan_$(DEVUAN_VERSION)_virtual.qcow2.xz:
	wget https://files.devuan.org/devuan_jessie/virtual/devuan_jessie_1.0.0_amd64_virtual.qcow2.xz
	wget https://files.devuan.org/devuan_jessie/virtual/SHA256SUMS
	sha256sum -c --ignore-missing SHA256SUMS

devuan_$(DEVUAN_VERSION)_virtual.qcow2: devuan_$(DEVUAN_VERSION)_virtual.qcow2.xz
	unxz --keep $<

packages/one-context_$(ONECONTEXT_VERSION).deb:
	mkdir -p packages
	cd packages
	wget https://github.com/OpenNebula/addon-context-linux/releases/download/v$(ONECONTEXT_VERSION)/one-context_$(ONECONTEXT_VERSION).deb
	touch $@

packages.iso: packages/one-context_$(ONECONTEXT_VERSION).deb
	genisoimage -o packages.iso -R -J -V PACKAGES packages/
	touch $@

devuan_$(DEVUAN_VERSION)_opennebula.qcow2: devuan_$(DEVUAN_VERSION)_virtual.qcow2 packages.iso contextualize.sh
	cp $< $@
	@echo Neet root privileges for virt-customize
	sudo virt-customize -v --format qcow2 --add $@ --no-network --attach packages.iso --run contextualize.sh --root-password disabled
	# virt-sparsify --in-place $@

##### Helper targets

clean:  ## Removes files listed in ./.gitignore
	rm -f $$(cat ./.gitignore | grep -v '^#')

