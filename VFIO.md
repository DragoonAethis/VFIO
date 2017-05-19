# Configs
- /etc/modprobe.d/vfio.conf: GPU to rebind.
- /etc/mkinitcpio.conf: vfio modules to load in the kernel.

After editing modules: mkinitcpio -p linux-ck

<qemu:env name='QEMU_AUDIO_TIMER_PERIOD' value='99'/>

# Message-signalled Interrupts
http://forums.guru3d.com/showthread.php?t=378044

Checking for PCI devices working in MSI-mode.
Go to Device Manager. Click in menu "View -> Resources by type". Expand "Interrupt request (IRQ)" node of the tree. Scroll down to "(PCI) 0x... (...) device name" device nodes. Devices with positive number for IRQ (like "(PCI) 0x00000011 (17) ...") are in Line-based interrupts-mode. Devices with negative number for IRQ (like "(PCI) 0xFFFFFFFA (-6) ...") are in Message Signaled-based Interrupts-mode.

Trying to switch device to MSI-mode.
You must locate device`s registry key. Invoke device properties dialog. Switch to "Details" tab. Select "Device Instance Path" in "Property" combo-box. Write down "Value" (for example "PCI\VEN_1002&DEV_4397&SUBSYS_1609103C&REV_00\3&11 583659&0&B0"). This is relative registry path under the key "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Enum\ ".

Go to that device`s registry key ("HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Enum \PCI\VEN_1002&DEV_4397&SUBSYS_1609103C&REV_00\3&11 583659&0&B0") and locate down the subkey "Device Parameters\Interrupt Management". For devices working in MSI-mode there will be subkey "Device Parameters\Interrupt Management\MessageSignaledInterruptProperties" and in that subkey there will be DWORD value "MSISupported" equals to "0x00000001". To switch device from legacy- to MSI-mode just add these subkey and value.

# Perf Tuning
https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7-Beta/html/Virtualization_Tuning_and_Optimization_Guide/index.html

# Samba Services
- smbd
- nmbd

# Components

echo "Unloading nvidia driver..."
sudo /etc/init.d/nvidia-smi stop > /dev/null
sudo rmmod nvidia

echo "Unbinding GPU..."
for dev in "0000:01:00.0" "0000:01:00.1"; do
	vendor=$(cat /sys/bus/pci/devices/${dev}/vendor)
	device=$(cat /sys/bus/pci/devices/${dev}/device)
	if [ -e /sys/bus/pci/devices/${dev}/driver ]; then
		echo "${dev}" | sudo tee /sys/bus/pci/devices/${dev}/driver/unbind > /dev/null
		while [ -e /sys/bus/pci/devices/${dev}/driver ]; do
			sleep 0.1
		done
	fi

	echo "Binding GPU to vfio-pci..."
	echo "${vendor} ${device}" | sudo tee /sys/bus/pci/drivers/vfio-pci/new_id > /dev/null
done
echo "Done."

# -> Run VM Here!

echo "Unbinding GPU..."
for dev in "0000:01:00.0" "0000:01:00.1"; do
	vendor=$(cat /sys/bus/pci/devices/${dev}/vendor)
	device=$(cat /sys/bus/pci/devices/${dev}/device)
	if [ -e /sys/bus/pci/devices/${dev}/driver ]; then
		echo "${dev}" | sudo tee /sys/bus/pci/devices/${dev}/driver/unbind > /dev/null
		while [ -e /sys/bus/pci/devices/${dev}/driver ]; do
			sleep 0.1
		done
	fi
done
echo "Done."

echo "Binding GPU to nvidia..."
sudo modprobe nvidia
sudo /etc/init.d/nvidia-smi start > /dev/null
