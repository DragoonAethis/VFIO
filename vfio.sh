#!/bin/bash

vfio_iommu_groups() {
	shopt -s nullglob
	for d in /sys/kernel/iommu_groups/*/devices/*; do
		n=${d#*/iommu_groups/*}; n=${n%%/*}
		printf 'IOMMU Group %s ' "$n"
		lspci -nns "${d##*/}"
	done;
}

vfio_start_barrier() {
	echo "Starting Barrier..."
	barrierc --debug WARNING --name sigurd --no-tray --enable-crypto WinVM.lan
}

vfio_switch_displays() {
	echo "Switching outputs..."
	xrandr --output HDMI-1 --off
	xrandr --output HDMI-2 --mode 1920x1080 --pos 0x0 --primary
	xrandr --output HDMI-2 --set "Broadcast RGB" "Full"
}

vfio_restore_displays() {
	echo "Restoring outputs..."
	xrandr --output HDMI-1 --mode 2560x1440 --rate 60 --pos 0x0 --primary
	xrandr --output HDMI-1 --set "Broadcast RGB" "Full"
    xrandr --output HDMI-2 --right-of HDMI-1 --mode 1920x1080 --rate 60 --pos 2560x270
    xrandr --output HDMI-2 --set "Broadcast RGB" "Full"
}

vfio_enable_hugepages() {
	echo -n "Compacting memory... "
    echo 1 | sudo tee /proc/sys/vm/compact_memory
    echo -n "Enabling hugepages... "
	echo 10 | sudo tee /proc/sys/vm/nr_hugepages

	echo -n "Allocated: "
	sudo cat /proc/sys/vm/nr_hugepages
}

vfio_disable_hugepages() {
	echo -n "Disabling hugepages... "
	echo 0 | sudo tee /proc/sys/vm/nr_hugepages
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
			return 0
		else
			echo $status
			read -p "Remount RO? (Y/N) " choice
			case "$choice" in
				y|Y )
					hdd_mount_ro
					if hdd_assert_ro; then return 0; else return 1; fi
				;;
				n|n )
					read -p "You're about to break your file system. Are you sure? Type YES to confirm: " wellfuck
					case "$wellfuck" in
						YES ) echo "Good luck!"; return 0 ;;
						*) return 1 ;;
					esac
				;;
				* )
                    echo "Invalid input, exiting..."
                    return 1
                ;;
			esac
		fi
	fi
}

vfio_winvm() {
	if hdd_assert_ro; then echo "HDD available!"; else echo "HDD unavailable, exiting..."; return 1; fi
	vfio_enable_hugepages

	# If no arguments are given, switch displays.
	[ $# -eq 0 ] && vfio_switch_displays

	echo "Starting Windows VM..."
	sudo virsh start Windows8.1
	sleep 1

	vfio_start_barrier
	while [[ $(pgrep qemu-system) ]]; do
		sleep 5
	done

	echo "QEMU no longer running, killing Barrier..."
	killall barrierc

	[ $# -eq 0 ] && vfio_restore_displays
}
