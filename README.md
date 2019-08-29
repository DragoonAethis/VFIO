**Warning:** I no longer use VFIO. All of these instructions and configs are
up to date as of this writing, plus feel free to ask questions in issues/via
mail if you aren't sure about something, but it'll no longer be updated.

Instead of VFIO I just use a normal dual boot, since the VM overhead starts
to become a problem in newer games with an older CPU I have, and the primary
reason I've used VFIO (Windows + Linux development box, side by side, with
little to no compromises) is no more. And I mostly play on Linux nowadays :D

---

# VFIO Setup

Files in this repository are my scripts, notes and "all the helper stuff" for
configuring the GPU passthrough and the guest VM. Essentially, native-level
performance for games in Windows, without dual booting. This was done on Arch
Linux, on other distros your mileage may vary (especially with outdated QEMU).

- If you'd like to try such a setup yourself, [try this ArchWiki page](https://wiki.archlinux.org/index.php/PCI_passthrough_via_OVMF).
- My setup is described a bit better on [the VFIO examples page](https://wiki.archlinux.org/index.php?title=PCI_passthrough_via_OVMF/Examples).

The vfio.sh is sourced in my .bashrc, so that I can just run `vfio_winvm` and
that's it. Passing any extra argument to vfio_winvm skips switching displays.
The VM will fail to start if any attached USB devices are missing - for that,
I use [tinyvirt](https://github.com/DragoonAethis/tinyvirt) to detach those and
then run the VM normally (used to have a separate domain, but I'm too lazy to
maintain them both :P).

## IOMMU Groups

    IOMMU Group 0 00:00.0 Host bridge [0600]: Intel Corporation Skylake Host Bridge/DRAM Registers [8086:191f] (rev 07)
    IOMMU Group 1 00:01.0 PCI bridge [0604]: Intel Corporation Skylake PCIe Controller (x16) [8086:1901] (rev 07)
    IOMMU Group 1 01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GP104 [GeForce GTX 1070] [10de:1b81] (rev a1)
    IOMMU Group 1 01:00.1 Audio device [0403]: NVIDIA Corporation GP104 High Definition Audio Controller [10de:10f0] (rev a1)
    IOMMU Group 2 00:02.0 VGA compatible controller [0300]: Intel Corporation HD Graphics 530 [8086:1912] (rev 06)
    IOMMU Group 3 00:14.0 USB controller [0c03]: Intel Corporation Sunrise Point-H USB 3.0 xHCI Controller [8086:a12f] (rev 31)
    IOMMU Group 4 00:16.0 Communication controller [0780]: Intel Corporation Sunrise Point-H CSME HECI #1 [8086:a13a] (rev 31)
    IOMMU Group 5 00:17.0 SATA controller [0106]: Intel Corporation Sunrise Point-H SATA controller [AHCI mode] [8086:a102] (rev 31)
    IOMMU Group 6 00:1b.0 PCI bridge [0604]: Intel Corporation Sunrise Point-H PCI Root Port #17 [8086:a167] (rev f1)
    IOMMU Group 7 00:1b.2 PCI bridge [0604]: Intel Corporation Sunrise Point-H PCI Root Port #19 [8086:a169] (rev f1)
    IOMMU Group 8 00:1b.3 PCI bridge [0604]: Intel Corporation Sunrise Point-H PCI Root Port #20 [8086:a16a] (rev f1)
    IOMMU Group 9 00:1c.0 PCI bridge [0604]: Intel Corporation Sunrise Point-H PCI Express Root Port #1 [8086:a110] (rev f1)
    IOMMU Group 10 00:1c.4 PCI bridge [0604]: Intel Corporation Sunrise Point-H PCI Express Root Port #5 [8086:a114] (rev f1)
    IOMMU Group 11 00:1d.0 PCI bridge [0604]: Intel Corporation Sunrise Point-H PCI Express Root Port #9 [8086:a118] (rev f1)
    IOMMU Group 12 00:1f.0 ISA bridge [0601]: Intel Corporation Sunrise Point-H LPC Controller [8086:a145] (rev 31)
    IOMMU Group 12 00:1f.2 Memory controller [0580]: Intel Corporation Sunrise Point-H PMC [8086:a121] (rev 31)
    IOMMU Group 12 00:1f.3 Audio device [0403]: Intel Corporation Sunrise Point-H HD Audio [8086:a170] (rev 31)
    IOMMU Group 12 00:1f.4 SMBus [0c05]: Intel Corporation Sunrise Point-H SMBus [8086:a123] (rev 31)
    IOMMU Group 13 00:1f.6 Ethernet controller [0200]: Intel Corporation Ethernet Connection (2) I219-V [8086:15b8] (rev 31)
    IOMMU Group 14 05:00.0 PCI bridge [0604]: Intel Corporation DSL6540 Thunderbolt 3 Bridge [Alpine Ridge 4C 2015] [8086:1578] (rev 03)
    IOMMU Group 15 06:00.0 PCI bridge [0604]: Intel Corporation DSL6540 Thunderbolt 3 Bridge [Alpine Ridge 4C 2015] [8086:1578] (rev 03)
    IOMMU Group 16 06:01.0 PCI bridge [0604]: Intel Corporation DSL6540 Thunderbolt 3 Bridge [Alpine Ridge 4C 2015] [8086:1578] (rev 03)
    IOMMU Group 17 06:02.0 PCI bridge [0604]: Intel Corporation DSL6540 Thunderbolt 3 Bridge [Alpine Ridge 4C 2015] [8086:1578] (rev 03)
    IOMMU Group 17 09:00.0 USB controller [0c03]: Intel Corporation DSL6540 USB 3.1 Controller [Alpine Ridge] [8086:15b6] (rev 03)
    IOMMU Group 18 06:04.0 PCI bridge [0604]: Intel Corporation DSL6540 Thunderbolt 3 Bridge [Alpine Ridge 4C 2015] [8086:1578] (rev 03)


## Configuration

- There are some system config files in the `/etc` directory in this repo.
- `/etc/modprobe.d/vfio.conf`: vfio-pci module options, basically the device
  IDs to rebind - `options vfio-pci ids=10de:1b81,10de:10f0` for the GPU.
- /etc/mkinitcpio.conf: vfio-pci needs to be early-loaded, building the kernel
  image with it is required. Without this, GPU may be claimed by nouveau:
  `MODULES="vfio vfio_iommu_type1 vfio_pci vfio_virqfd i915"`
- Hugepages are used for VM memory backing - put this in your kernel cmdline:
  `hugepagesz=1GB default_hugepagesz=1G transparent_hugepage=never` and this in
  your `/etc/fstab`: `hugetlbfs /hugepages hugetlbfs mode=1770,gid=78 0 0`. All
  of this will not enable hugepages on boot, but rather allocate them when the
  VM starts. Since those pages are now 1GB each, your system might not be able
  to enable them all after fragmenting its memory - just reboot and try again.

After editing modules, this rebuilds the kernel image: `# mkinitcpio -p linux`


## Hugepages

Until the recent Meltdown/Spectre patches, the VM had some occasional, short
"hiccups" (Decepticon sounds along with the VM hanging for ~0.2s). Occasional,
so I didn't really mind that much - it was irritating, but not enough to fix it
until very recently. After PTI patches, those hiccups started to occur way more
often (every ~10s or so), which made most games unplayable. After some tweaks
with CPU pinning and using hugepages for VM memory, most problems went away for
good - the only problem is that now hugepages are required for the VM to work.

[This ArchWiki page explains how to set them up.](https://wiki.archlinux.org/index.php/PCI_passthrough_via_OVMF#Static_huge_pages)

Now, the article says that only static hugepages are supported and it appears
to be correct - QEMU crashed with transparent hugepages enabled. However, I
play games rather rarely as of late and I'm not up for having 10GBs of RAM in
there consumed just because I might play games like once a week - instead, the
script used to start the VM enables them on demand (`vfio_enable_hugepages`).
To do the same in your setup, skip `hugepages=X` in the kernel parameters.

There's a big problem with this approach, through: After the system has booted
up, the memory gets fragmented very quickly, so allocating 1GB hugepages gets
problematic - the system will allocate only up to the amount of pages that it
can find space for, and after running a few applications there's virtually no
contiguous, free 1GB blocks of memory to allocate. To fix this, reboot your
computer and run the VM right after your system has started. Once allocated,
you can keep using both the VM and host normally (hugepages aren't getting
deallocated on VM shutdown, since I might want to restart it or something -
`vfio_disable_hugepages` does so, but once you run that, you probably won't be
able to allocate these pages again until reboot).


## Message-Signalled Interrupts

[This Guru3D thread](http://forums.guru3d.com/showthread.php?t=378044) explains
how to configure and manage MSI for devices under Windows. It allows devices to
perform interrupts with standard PCI messages instead of the interrupt line,
which behaves a bit nicer under QEMU. The linked "MSI utility v2" is okay, but
be careful not to turn on MSI for some devices like the SATA controllers, since
Windows might no longer boot after that (load last known good configuration in
the Boot Manager to get it running again, but DISABLE MSI for those devices).

Checking whenever a device has MSI enabled:
- Open the Device Manager.
- Menu "View -> Resources by type". Expand "Interrupt request (IRQ)".
- PCI devices with negative IRQ numbers have MSI enabled.

Also, driver updates tend to disable MSI, so visit that utility periodically.


## PulseAudio Setup (Legacy)

I've fixed a couple of other things preventing me from running QEMU as my own
user account, so I don't need to do the stuff below anymore (QEMU_PA_SERVER now
points at the local Unix socket). For documentation purposes, my previous setup
is still documented below. This lets you run QEMU as nobody/nogroup and still
have working audio, with minimal extra latency.

---

Finally got PulseAudio to work flawlessly - normally, QEMU needs to be run as
the user owning the running PA server. This breaks a few other things though,
so I tried to find another way to connect to PA. It turns out PA supports TCP
sockets as a standard transport, built-in, just needs to be enabled. Install
and get PulseAudio running, then in `/etc/pulse/default.pa` edit the line:

    #load-module module-native-protocol-tcp

...to:

    load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1;192.168.1.0/24 auth-anonymous=1

Save that file and restart PulseAudio.

This allows anybody in your local network (192.168.1.1-254) and on your PC to
connect to the PA daemon without authentication (`auth-anonymous=1`). Normally
PA requires the connecting party to own a shared "cookie", but the `nobody`
user QEMU runs under can't have that - since I trust everyone in my network not
to play disco polo at 3am on my computer while I'm sleeping next to it, it's
fine for now. It'd be nice to find a lightweight auth scheme (shared password
in the PA connection string, or something like that?), though.

In your domain file, at the very top, replace this:

    <domain type='kvm'>

...with this:

    <domain type='kvm' xmlns:qemu='http://libvirt.org/schemas/domain/qemu/1.0'>

Then, under the `<devices>...</devices>` section, put this:

    <qemu:commandline>
      <qemu:env name='QEMU_AUDIO_DRV' value='pa'/><!-- Use PulseAudio for ICH6 output -->
      <qemu:env name='QEMU_PA_SERVER' value='127.0.0.1'/><!-- Using the IP address uses TCP, not Unix, sockets! -->
    </qemu:commandline>

*Et voila!* We have sound. You might want to restart the VM, or make sure PA
actually reloaded the default.pa config file (with `pactl list-modules`), for
everything to start working.

**As of QEMU 3.0** you also need to make sure your emulated machine is at least
`pc-q35-3.0` or newer (in libvirt's XML files, the line to edit is
`<type arch='x86_64' machine='pc-q35-3.0'>hvm</type>`). Some improvements were
made to the emulated audio card, but they'll only be enabled if you explicitly
ask for the latest machine model. (Latest machine type is `pc-q35-3.1` and is
perfectly fine, too.)

If your audio still gets a bit Decepticon-ish, you might need a patched QEMU
build - there's a QEMU fork with a new PulseAudio backend that's way less
glitchy, [made by Spheenik](https://github.com/spheenik/qemu/). Arch users can
use [this AUR package](https://aur.archlinux.org/packages/qemu-patched) which
uses those patches on the latest QEMU version. Also see the note on Linux-ck
below, if you're using that.


## Linux-ck Stuttering

For a long while I've used the [CK patchset](https://ck-hack.blogspot.com/) for
its superb desktop responsiveness under high I/O load. For some reason, recent
versions (since MuQSS introduction?) introduced very nasty stuttering in gaming
VMs that ranges from irritating to deal-breaking. Vanilla kernel doesn't do any
of this, and the I/O scheduler that made responsiveness so good on HDDs (BFQ)
is available as well (it wasn't when I've started to use Linux-ck).

So, if you're using Linux-ck and experiencing insane stuttering, try vanilla
kernel instead. (Would be nice to test with `linux-clear` one day...)


## Using NVIDIA GPU on the host

If you're not planning on gaming for a bit, you may want to switch your host to
the NVIDIA GPU temporarily. [nvidia-xrun](https://github.com/Witko/nvidia-xrun)
provides configuration and helper scripts to run X.org on the NVIDIA GPU with a
separate command and separate `.xinitrc` called `.nvidia-xrun`.

On my system, `.nvidia-xrun` basically contains the same stuff as `.xinitrc`,
so that it starts the same desktop environment, uses same config files, etc.
To run it, you'll need to `sudo rmmod vfio-pci` first, and then `nvidia-xrun`
(it automatically loads the NVIDIA kernel driver and sets up everything you
need, aside from unloading the vfio-pci driver).
