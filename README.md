# VFIO Setup

Files in this repository are my scripts, notes and "all the helper stuff"
related with configuring the GPU passthrough and the guest VM. Essentially,
native-level performance for games in Windows, without dual booting. This
was done on Arch Linux, on other distros your mileage may vary (especially
with outdated libvirt/QEMU).

If you'd like to try such a setup yourself, [try this ArchWiki page](https://wiki.archlinux.org/index.php/PCI_passthrough_via_OVMF).

My setup is described a bit better on [the VFIO examples page](https://wiki.archlinux.org/index.php?title=PCI_passthrough_via_OVMF/Examples).

The VM is started with either `WinVM.sh` or `JustVM.sh`, the first one starts
Windows8.1 and does some magic with displays, the second uses Windows8.1-NoRedir
and doesn't switch displays/start Synergy/etc.

It's exactly the same domain, except that it doesn't pass through any USB devices.
Used mostly for remote access when I've unplugged the mouse (libvirt will fail
to start the VM if one of the passed devices are unavailable).

## PulseAudio Setup

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
      <qemu:env name='QEMU_AUDIO_DRV' value='pa'/><!-- Use PulseAudio for ICH9 output -->
      <qemu:env name='QEMU_PA_SERVER' value='127.0.0.1'/><!-- Using the IP address uses TCP, not Unix, sockets! -->
    </qemu:commandline>

*Et voila!* We have sound. You might want to restart the VM, or make sure PA
actually reloaded the default.pa config file (with `pactl list-modules`), for
everything to start working.
