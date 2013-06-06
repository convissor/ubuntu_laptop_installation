Ubuntu Laptop Installation
==========================

Instructions and bash scripts for installing and configuring Ubuntu 12.04
on a PC laptop.  Notable features:

* Encrypts entire hard drive
* Tracks all changes to `/etc` via git
* Installs common utilities
* Sets up administrative access via `ssh root@localhost`


Prepare Installation Media
==========================

* [Obtain the `alternate` installer](http://releases.ubuntu.com/12.04/)
* Put a USB stick in your existing computer.
* As user with sudo powers:  System | Administration | Startup Disk Creator
* Either add a partition to that thumb drive or get another drive and put
the contents of this GitHub repository onto it:

        usb_partition=transit
        cp -R ubuntu_laptop_installation /media/$usb_partition

        # To bring over other existing configurations for SSH, Firefox, etc.
        cp -R ~/.ssh /media/$usb_partition
        cp -R ~/.mozilla/firefox/<profile>/ /media/$usb_partition

* UNMOUNT USB DRIVE


Installation
=============

* Put USB drive in new computer
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
This prevents disruptive commands from being inadvertently executed.

Once the "Partition disks" screen comes up, pick: `Guided - use entire disk
and set up ecrypted LVM`


Configuration
=============

Once Ubuntu is installed, it is time to configure the system for and
install desirable utilities.

Fire up a terminal session.  Here are two possible ways:

1. ALT-F1, Enter, type in `terminal`, Enter
1. CTRL-ALT-T

Then issue the following commands:

    chmod 700 .

    sudo -i

    wget https://raw.github.com/convissor/ubuntu_laptop_installation/master/setup.sh
    chmod 700 setup.sh
    ./setup.sh

The last step of the setup script updates the kernel.  If that's needed,
it'll automatically reboot the computer.  If for some reason the reboot
isn't required, that's cool.  Just log out from the administrator account.


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

To change the password of the encrypted drive.  Watch bootup for which device
is being decrypted (eg: `sda5_crypt`).  If the drive is something other than
`sda5`, adjust the commands as needed.

    cryptsetup luksAddKey /dev/sda5
    cryptsetup luksDump /dev/sda5
    cryptsetup luksKillSlot /dev/sda5 0

Apparently, one can back up the drive encryption headers this way:

    luksHeaderBackup /dev/sda5 --header-backup-file <file>
