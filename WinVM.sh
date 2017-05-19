#!/bin/bash
source Library.sh
hdd_test_rw

[ $# -eq 0 ] && vfio_switch_displays

# VM goes up here:
echo "Starting Windows VM..."
sudo virsh start Windows8.1

sleep 3

while [[ $(pgrep qemu-system) ]]
do
	if [[ ! $(pgrep synergyc) ]]
	then
		vfio_synergy
	fi

	sleep 3
done

echo "QEMU no longer running, killing Synergy..."
killall synergyc

[ $# -eq 0 ] && vfio_restore_displays

echo "VM down, system restored."
