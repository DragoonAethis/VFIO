#!/bin/bash

vfio_iommu_groups() {
	shopt -s nullglob
	for d in /sys/kernel/iommu_groups/*/devices/*; do
		n=${d#*/iommu_groups/*}; n=${n%%/*}
		printf 'IOMMU Group %s ' "$n"
		lspci -nns "${d##*/}"
	done;
}

vfio_start_synergy() {
	echo "Starting Synergy..."
	synergyc --debug WARNING --name sigurd 192.168.1.4
}

vfio_switch_displays() {
	echo "Switching outputs..."
	xrandr --output HDMI-2 --off
	xrandr --output HDMI-1 --mode 1920x1080 --pos 0x0 --primary
	xrandr --output HDMI-1 --set "Broadcast RGB" "Full"
}

vfio_restore_displays() {
	echo "Restoring outputs..."
	xrandr --output HDMI-2 --mode 1920x1080 --pos 0x0 --primary
	xrandr --output HDMI-2 --set "Broadcast RGB" "Full"
	xrandr --output HDMI-1 --mode 1920x1080 --pos 1920x0
	xrandr --output HDMI-1 --set "Broadcast RGB" "Full"
}

# Force remove the GPU from the system and rescan the PCI bus.
# This basically performs a hardware reset.
vfio_gpu_redetect() {
   echo -n "Removing the GPU... "
	echo 1 | sudo tee /sys/bus/pci/devices/0000:01:00.0/remove

	echo -n "Removing HDMI Audio... "
	echo 1 | sudo tee /sys/bus/pci/devices/0000:01:00.1/remove

	echo -n "Rescanning PCI devices... "
	echo 1 | sudo tee /sys/bus/pci/rescan
}

vfio_enable_hugepages() {
	echo -n "Enabling hugepages... "
	echo 10 | sudo tee /proc/sys/vm/nr_hugepages

	echo -n "Allocated: "
	sudo cat /proc/sys/vm/nr_hugepages
}

vfio_disable_hugepages() {
	echo -n "Disabling hugepages... "
	echo 0 | sudo tee /proc/sys/vm/nr_hugepages
}

# Force unbind both GPU devices from the system. **WILL CRASH X.ORG IF GPU BOUND TO NOUVEAU!**
vfio_gpu_unbind() {
	echo "0000:01:00.0" | sudo tee /sys/bus/pci/devices/0000:01:00.0/driver/unbind
	echo "0000:01:00.1" | sudo tee /sys/bus/pci/devices/0000:01:00.1/driver/unbind
	sudo rmmod nouveau
	sudo rmmod vfio-pci
}

# Bind GPU to the nouveau driver and HDMI audio to snd_hda_intel. **WILL CRASH X.ORG!**
vfio_gpu_bind_nouveau() {
	sudo modprobe nouveau
	echo "0000:01:00.0" | sudo tee /sys/bus/pci/drivers/nouveau/bind
	echo "0000:01:00.1" | sudo tee /sys/bus/pci/drivers/snd_hda_intel/bind
}

# Bind both GPU devices to the vfio-pci driver.
vfio_gpu_bind_vfio() {
	sudo modprobe vfio-pci
	echo "0000:01:00.0" | sudo tee /sys/bus/pci/drivers/vfio-pci/bind
	echo "0000:01:00.1" | sudo tee /sys/bus/pci/drivers/vfio-pci/bind
}

hdd_mount_ro() {
	sudo umount /mnt/Seagate2TB
	sudo mount /mnt/Seagate2TB -o ro,nosuid,nodev,noexec,relatime,user_id=0,group_id=0,default_permissions,allow_other,blksize=4096,user
}

hdd_mount_rw() {
	sudo umount /mnt/Seagate2TB
	sudo mount /mnt/Seagate2TB -o rw,nosuid,nodev,noexec,relatime,user_id=0,group_id=0,default_permissions,allow_other,blksize=4096,user
}

hdd_assert_ro() {
	mountpoint /mnt/Seagate2TB
	if [ "$?" -eq "0" ]; then
		status=$(mount | grep Seagate2TB | grep rw)

		if [ "$status" = "" ]; then
			echo "HDD RO, ok"
		else
			echo $status

			read -p "Remount RO? (Y/N)" choice
			case "$choice" in
				y|Y )
					hdd_mount_ro
					hdd_assert_ro
				;;
				n|n )
					read -p "You're about to break your file system. Are you sure? (y/NNNNN)" wellfuck
					case "$wellfuck" in
						y|Y ) echo "Good luck!" ;;
						*) exit ;;
					esac
				;;
				* ) echo "Something bad happened, leaving..."; exit ;;
			esac
		fi
	fi
}

vfio_just_vm() {
	hdd_assert_ro
	sudo virsh start Windows8.1-NoRedir
}

vfio_winvm() {
	hdd_assert_ro
	vfio_enable_hugepages

	# If no arguments are given, switch displays.
	[ $# -eq 0 ] && vfio_switch_displays

	echo "Starting Windows VM..."
	sudo virsh start Windows8.1
	sleep 1

	vfio_start_synergy
	while [[ $(pgrep qemu-system) ]]; do
		sleep 5
	done

	echo "QEMU no longer running, killing Synergy..."
	killall synergyc

	vfio_disable_hugepages
	[ $# -eq 0 ] && vfio_restore_displays
}
