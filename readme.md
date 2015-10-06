Ubuntu (Laptop) Installation
============================

Instructions and bash scripts for installing and configuring Ubuntu 15.04
(Vivid Vervit) on a PC.
The initial intention was using this on laptops.  In reality, it works great for
desktops too.

See this repository's "14.04" branch for setting up Trusty Tahr or
Saucy Salamander.

See this repository's "12.04" branch for setting up Precise Pangolin.

Notable features:

* Encrypts entire hard drive
* Ensures swap space is working and encrypted
* Tracks all changes to `/etc` and `/usr/share/glib-2.0/schemas` via git
* Sets up administrative access via `ssh root@localhost`
* Installs common utilities
* Installs `ctags` from source (to obtain bug fixes for PHP parsing)
* Installs scripts for running ctags on Git and Subversion repositories
* Optionally installs my vim settings (part of which uses all the ctag magic, above)
* Includes a shell script to install Netflix Desktop


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
into the BIOS setup mode.  Here are two examples:

Lenovo E31 ThinkStation
-----------------------
* When booting, repeatedly hit F1 until the BIOS screen appears
* Startup
	* Boot Mode: Legacy
	* Quick Boot: Disabled
* Devices
	* Configure SATA as: ACHI

Asus H87M-PRO Motherboard
-------------------------
* When booting, repeatedly hit DELETE until the BIOS screen appears
* F7 for Advanced Mode
* Boot
* Secure Boot: OS Type: Other OS
* Save and reboot

More Information
----------------
https://help.ubuntu.com/community/UEFI


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
* If you get a message saying "gfxboot.c32: not a COM32R image", type "live" and hit Enter.
* If the small bar (USB logo?) appears, hit Enter
* If things do not progress, hit Enter again

Now you're in Ubuntu's installer.

The "Preparing to install Ubuntu" page has the
"Download updates while installing" checkbox, but DON'T check it.
Save yourself the agony.  Ubuntu's default repository is horribly slow.  My
setup script changes it to a faster repository and then updates everything.
Do check the "Install this third-party software" box to make life simpler.

On the "Installation type" screen, ensure the "Erase disk and install
Ubuntu" radio button is selected.  Then put checks in the
"Encrypt the new Ubuntu installation for security" and
"Use LVM with the new Ubuntu installation" boxes.

When you are asked to "Pick a username" on the "Who are you?" screen,
DO __NOT__ use your company assigned user name.
A regular user name account will be created later.
This first account is an admin user with sudo privileges; it should be a
separate account from the one you use on a day-to-day basis for regular work.
This prevents destructive commands from being inadvertently executed.

Also on that screen, pick the "Require my password to log in" radio button.
While picking "Encrypt my home folder" isn't essential because the whole
drive is encrypted, picking it is another safety measure in the event other
users are given accounts on the machine.


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

    apt-get update && apt-get install git-core git-doc
    git clone git://github.com/convissor/ubuntu_laptop_installation.git
    cd ubuntu_laptop_installation
    git checkout 15.04

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

    cryptsetup luksHeaderBackup /dev/sda5 --header-backup-file <file>
