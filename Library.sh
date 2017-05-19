#!/bin/bash

iommu_groups() {
	shopt -s nullglob
	for d in /sys/kernel/iommu_groups/*/devices/*; do
		n=${d#*/iommu_groups/*}; n=${n%%/*}
		printf 'IOMMU Group %s ' "$n"
		lspci -nns "${d##*/}"
	done;
}

vfio_synergy() {
	echo "Starting Synergy..."
	synergyc --debug ERROR --name sigurd 192.168.1.4:24800
}

vfio_switch_displays() {
	echo "Switching outputs..."
	xrandr --output HDMI2 --off
	xrandr --output DP1 --mode 1920x1080 --pos 0x0 --primary
	xrandr --output DP1 --set "Broadcast RGB" "Full"
}

vfio_restore_displays() {
	echo "Restoring outputs..."
	xrandr --output HDMI2 --mode 1920x1080 --pos 0x0 --primary
	xrandr --output DP1 --mode 1920x1080 --pos 1920x0
	xrandr --output DP1 --set "Broadcast RGB" "Full"
}

# THIS DOESN'T WORK YET, DO NOT TRY THIS AT HOME.
gpu_rebind() {
	echo 1 > /sys/bus/pci/devices/0000:01:00.0/remove
	echo 1 > /sys/bus/pci/devices/0000:01:00.1/remove
	echo 1 > /sys/bus/pci/rescan
}

# THIS DOESN'T WORK YET, DO NOT TRY THIS AT HOME.
gpu_unbind() {
	echo "10de 1b81" > /sys/bus/pci/drivers/vfio-pci/new_id
	echo "0000:01:00.0" > /sys/bus/pci/devices/0000:01:00.0/driver/unbind
	echo "0000:01:00.0" > /sys/bus/pci/drivers/vfio-pci/bind
	echo "10de 1b81" > /sys/bus/pci/drivers/vfio-pci/remove_id

	echo "10de 10f0" > /sys/bus/pci/drivers/vfio-pci/new_id
	echo "0000:01:00.1" > /sys/bus/pci/devices/0000:01:00.1/driver/unbind
	echo "0000:01:00.1" > /sys/bus/pci/drivers/vfio-pci/bind
	echo "10de 10f0" > /sys/bus/pci/drivers/vfio-pci/remove_id
}

hdd_ro() {
	sudo mount /mnt/Seagate2TB -o ro,nosuid,nodev,noexec,relatime,user_id=0,group_id=0,default_permissions,allow_other,blksize=4096,user
}

hdd_rw() {
	sudo mount /mnt/Seagate2TB -o rw,nosuid,nodev,noexec,relatime,user_id=0,group_id=0,default_permissions,allow_other,blksize=4096,user
}

hdd_umount() {
	sudo umount /mnt/Seagate2TB
}

hdd_test_rw() {
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
					hdd_umount
					hdd_ro

					hdd_test_rw
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
