Ubuntu Laptop Installation
==========================

Instructions and bash scripts for installing and configuring Ubuntu 14.04
(Trusty Tahr) on a PC laptop.  Notable features:

* Encrypts entire hard drive
* Tracks all changes to `/etc` and `/usr/share/glib-2.0/schemas` via git
* Installs common utilities
* Sets up administrative access via `ssh root@localhost`
* Includes a shell script to install Netflix Desktop

WARNING: 14.04 has not been released yet.  It and these instructions are
experimental.


Prepare Installation Media
==========================

* [Obtain the "live" demo / installer](http://cdimage.ubuntu.com/daily-live/current/trusty-desktop-amd64.iso)
* Put a USB stick in your existing computer
* As a user with sudo powers:  System | Administration | Startup Disk Creator
* Unmount the USB drive and remove it

If Startup Disk Creator gives you problems, or you don't want to bother with
it, you can use `dd` to copy the ISO to your USB stick.

Note: the regular installer for 14.04 now includes the ability to implement
whole drive encryption.  In 12.04, one had to use the "alternate" installer.


Disable UEFI
============

UEFI is a process by which the BIOS monitors boot records.  This can keep
Ubuntu from booting.  To work around this problem, it's necessary to disable
UEFI __before__ installing the operating system.  Boot the computer and get
into the BIOS setup mode.  As an example, this is how I did it and the various
settings that need checking on a Lenovo E31 ThinkStation.

* When booting, repeatedly hit F1 until the BIOS screen appears
* Startup
	* Boot Mode: Legacy
	* Quick Boot: Disabled
* Devices
	* Configure SATA as: ACHI

For more information, see https://help.ubuntu.com/community/UEFI


Installation
=============

* Take the USB drive from the "Prepare Installation Media" step, above,
and put it in the new computer
* Hit the power button to turn the machine on

The following three steps are described for a Lenovo laptops in 2012.  If
you are using a different machine or BIOS versions, please improvise as
needed.

* When the BIOS splash screen appears, hit Enter, F12, select "USB HDD",
hit Enter
* When the small bar (USB logo?) appears, hit Enter
* If things do not progress, hit Enter again

Now you're in Ubuntu's installer.

When asked for a user name, DO __NOT__ use your company assigned user name.
A regular, company provided user name account will be created later.
This first account is an admin user with sudo privileges; it should be a
separate account from the one you use on a day-to-day basis for regular work.
This prevents destructive commands from being inadvertently executed.

When asked whether to encrypt the home directory, say no.  It's unnecessary
because the whole drive will be encrypted.

Once the "Partition disks" screen comes up, pick the option for encrypting
the whole drive.


Configuration
=============

Once Ubuntu is installed, it is time to configure the system and
install additional programs.

Fire up a terminal session.  Here are two possible ways:

1. ALT-F1, Enter, type in `terminal`, Enter
1. CTRL-ALT-T

Our setup process creates SSH keys for logging into the `root` account.
If you already have an SSH key you want to use for this purpose, copy it
over to `~/.ssh` now.

Then issue the following commands:

    chmod 700 .

    sudo -i

    wget https://raw.github.com/convissor/ubuntu_laptop_installation/14.04/setup.sh
    chmod 700 setup.sh
    ./setup.sh

The last step of the setup script updates the kernel, if necessary.  If that
update is needed, the script will automatically reboot the computer.  But if a
reboot isn't required; just log out of the administrator account and use
the "regular user" account the setup script had you create.


Wireless
========

* Log in to the laptop as the regular user
* Click on the Network Connections icon in the tray, and click on
"Edit Connections"
* On the "Wireless" tab, click "Add"
* Put the desired SSID
* In the "Device MAC address" box, pick one
* Uncheck "Connect automatically" and "Available to all users"
* Go to the "Wireless Security" tab
* Pick "WPA & WPA2 Personal" in the "Security" box
* Enter the password
* Click "Save"


Regular User Customization
==========================

If you want to bring over a Firefox profile, log in as the LDAP user, then:

    mkdir -p ~/.mozilla/firefox
    cp -R /media/<usb_partition>/<profile> ~/.mozilla/firefox
    firefox -ProfileManager &


Future Reference
================

You can log in as root via `ssh root@localhost`

To lock the screen, hit CTRL-ALT-L

To check DNS settings, call `nm-tool`

To install Netflix Desktop, run the `netflix-desktop.sh` script from this
repository

To change the password of the encrypted drive.  Watch bootup for which device
is being decrypted (eg: `sda5_crypt`).  If the drive is something other than
`sda5`, adjust the commands as needed.

    cryptsetup luksAddKey /dev/sda5
    cryptsetup luksDump /dev/sda5
    cryptsetup luksKillSlot /dev/sda5 0

Apparently, one can back up the drive encryption headers this way:

    luksHeaderBackup /dev/sda5 --header-backup-file <file>
