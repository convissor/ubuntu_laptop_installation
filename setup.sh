#! /bin/bash -e

if [[ $1 == "-h" || $1 == "--help" || $1 == "help" ]] ; then
    echo "Usage: setup.sh"
    echo ""
    echo "Configures a new Ubuntu 14.04 (or 13.10) machine."
    echo ""
    echo "Author: Daniel Convissor <danielc@analysisandsolutions.com>"
    echo "https://github.com/convissor/ubuntu_laptop_installation"
    exit 1
fi


function step_header() {
    echo "> > > > >  $1 START"
}

function ask_to_proceed() {
    echo "> > > > >  $1 DONE"
    echo ""
    echo ""

    # Uncomment the remaining lines if you want each step to ask you
    # whether to proceed or not.
    #echo -n "Hit CTRL-C to stop or ENTER to continue... "
    #read -e
}

function commit_if_needed() {
    cd /etc
    if [ -n "$(git status --porcelain)" ] ; then
        git commit -qam "$1"
    fi
}

repo_dir="$(cd "$(dirname "$0")" && pwd)"
admin_user=$(grep 1000 /etc/passwd | awk -F ':' '{print $1}')


# SETUP ROOT SSH KEYS =====================================

step="root ssh keys"
step_header "$step"

if [ ! -d /root/.ssh ] ; then
    make_keys=1
    dir="/home/$admin_user/.ssh"
    if [ -d "$dir" ] ; then
        make_keys=0
        echo "Copying $dir"
        cp -R "$dir" /root
    fi
else
    make_keys=0
fi

if [ $make_keys == 1 ] ; then
    mkdir -m 700 /root/.ssh
    cd /root/.ssh
    ssh-keygen -t rsa -C root@localhost -f id_rsa-root
    cp id_rsa-root.pub authorized_keys

cat >> config <<EOSSH
ForwardAgent no
Host localhost
IdentityFile ~/.ssh/id_rsa-root
EOSSH

else
    chmod 700 /root/.ssh
fi

set +e
chmod --quiet 600 /root/.ssh/*
set -e

ask_to_proceed "$step"


# TRACK ALL CONFIGURATION CHANGES =========================

step="put /etc under git control, install vim"
step_header "$step"

if [[ -z $(which git) || -z $(which vim) ]] ; then
    apt-get -qq update
    apt-get -qq -y install git-core vim
fi

if [[ ! -d /etc/.git ]] ; then
    cd /etc
    git init
    chmod 770 .git

    git config --global user.name root
    git config --global user.email root@localhost

    echo "mtab" >> .gitignore
    echo "cups/subscriptions*" >> .gitignore
    git add --all
    commit_if_needed "$step"
fi

ask_to_proceed "$step"


# GET SWAP WORKING AND/OR ENCRYPTED ===================
# https://bugs.launchpad.net/ubuntu/+source/ecryptfs-utils/+bug/953875
# https://bugs.launchpad.net/ubuntu/+source/ecryptfs-utils/+bug/1453738

step="get swap working and/or encrypted"
step_header "$step"

set +e
swapon_list=$(swapon -s | grep ^/)
set -e

if [ -z "$swapon_list" ] ; then
    echo "No swaps exist.  Let's fix that."
    swap=/dev/ubuntu-vg/swap_1
    swapon_crypt_count=0
else
    swap=(${swapon_list[@]})

    set +e
    swapon_crypt_count=$(/sbin/dmsetup table $swap | grep -c " crypt ")
    set -e

    if [ $swapon_crypt_count -eq 0 ] ; then
        echo "Regular swap exists.  Convert it to encrypted."
    else
        echo "Encrypted swap exists.  Move along."
    fi
fi

if [ $swapon_crypt_count -eq 0 ] ; then
    set +e
    uuid=$(blkid -o value -s UUID $swap)
    set -e
    if [ -z "$uuid" ] ; then
        echo "Couldn't determine UUID for $swap.  Using path instead."
        source_device=$swap
    else
        echo "$swap = $uuid"
        source_device="UUID=$uuid"
    fi

    set +e
    fstab_regular_count=$(grep -c ^/dev/mapper/ubuntu--vg-swap_1 /etc/fstab)
    set -e
    if [ $fstab_regular_count -ne 0 ] ; then
        echo "Comment out the unencrypted swap entry in fstab."
        sed -r "s@^(/dev/mapper/ubuntu--vg-swap_1)@#\1@" -i /etc/fstab
    fi

    set +e
    fstab_crypt_count=$(grep -c ^/dev/mapper/cryptswap1 /etc/fstab)
    set -e
    if [ $fstab_crypt_count -eq 0 ] ; then
        echo "Add cryptswap1 entry to fstab."
        echo "/dev/mapper/cryptswap1 none swap sw 0 0" >> /etc/fstab
    fi

    set +e
    crypttab_crypt_count=$(grep -c ^cryptswap1 /etc/crypttab)
    set -e
    if [ $crypttab_crypt_count -eq 0 ] ; then
        echo "Add cryptswap1 entry to crypttab."
        echo "cryptswap1 $source_device /dev/urandom swap,offset=1024,cipher=aes-cbc-essiv:sha256" >> /etc/crypttab
    else
        set +e
        source_count=$(grep -c "^cryptswap1 $source_device" /etc/crypttab)
        set -e
        if [ $source_count -eq 0 ] ; then
            echo "Set cryptswap1 source device to $source_device in crypttab."
            sed -r "s@^cryptswap1 [^[:space:]]+@cryptswap1 $source_device@" -i /etc/crypttab
        fi

        set +e
        offset_count=$(grep -c "^cryptswap1.*offset=" /etc/crypttab)
        set -e
        if [ $offset_count -eq 0 ] ; then
            echo "Add offset to cryptswap1 entry in crypttab."
            sed -r "s/swap,cipher/swap,offset=1024,cipher/" -i /etc/crypttab
        fi
    fi

    echo "Turn swaps off."
    swapoff -a

    echo "Restart cryptswap1."
    /etc/init.d/cryptdisks restart

    echo "Turn swaps back on."
    swapon -a

    echo "Result of swap reworking:"
    swapon -s
fi

cd /etc && git add --all && commit_if_needed "$step"
ask_to_proceed "$step"


# VIM SETTINGS FOR ROOT ===============================

cd
if [[ ! -d vim-settings ]] ; then
    git clone git://github.com/convissor/vim-settings.git
    cd vim-settings
else
    cd vim-settings
    # Ensure files have right permissions in case copied via thumb drive.
    git reset --hard HEAD
fi

if [[ ! -e ~/.vimrc ]] ; then
    ./setup.sh
fi

cd
if [[ ! -e /etc/skel/vim-settings ]] ; then
    cp -R vim-settings /etc/skel
fi


# CHANGE REPOSITORY =======================================
# The default us. repositories are VERRRRRRRRRY slow (eg 150 KB/s)

step="use pnl.gov repository instead of ubuntu's"
step_header "$step"
file=/etc/apt/sources.list

set +e
grep -q "mirror.pnl.gov" "$file"
if [ $? -ne 0 ] ; then
    set -e
    sed "s/us\.archive\.ubuntu\.com/mirror.pnl.gov/g" -i "$file"
    cd /etc && git add --all && commit_if_needed "$step"
    apt-get -qq update
    ask_to_proceed "$step"
else
    set -e
fi


# KERNEL UPGRADE ========================================
# Do now; 15.05 has bug regarding password for swap drive encryption.

step="kernel upgrade"
step_header "$step"

apt-get -qq dist-upgrade
cd /etc && git add --all && commit_if_needed "$step"

if [ -a /var/run/reboot-required ] ; then
    echo "REBOOT IS REQURED"
    echo "Once rebooted, re-run this startup.sh script to complete the process."
    echo -n "Press ENTER to continue..."
    read -e
    shutdown -r now
    exit
fi

ask_to_proceed "$step"


# MAKE GRUB USABLE ========================================

step="grub fixup"
step_header "$step"
file=/etc/default/grub
# Get grub menu to show by commenting out this option.
sed -r "s/(GRUB_HIDDEN_TIMEOUT.*)/#\1/g" -i "$file"
# Shorten timeout to 5 seconds.
sed -r "s/(GRUB_TIMEOUT=.*)$/GRUB_TIMEOUT=5/g" -i "$file"

# Get rid of "error: no video mode activated."
# https://bugs.launchpad.net/ubuntu/+source/grub2/+bug/699802
cp /usr/share/grub/*.pf2 /boot/grub

update-grub

cd /etc && git add --all && commit_if_needed "$step mods"
ask_to_proceed "$step"


# IPTABLES ================================================

step="iptables-persistent"
step_header "$step"

iptables_file=/etc/iptables/rules.v4
ip6tables_file=/etc/iptables/rules.v6

echo ""
echo "Say NO both times to the pop up asking to save the IP tables data."
echo -n "Press ENTER to continue..."
read -e

apt-get -qq -y install iptables-persistent
cd /etc && git add --all && commit_if_needed "$step"

dir=`dirname "$iptables_file"`
if [ ! -d "$dir" ] ; then
    mkdir -p "$dir"
fi

# -------------------------------------
cat > "$iptables_file" <<EOIPT
*filter
# Drop inbound packets unless specifically allowed by subsequent rules.
:INPUT DROP [0:0]
:FORWARD DROP [0:0]

# Outbound packets are fine.
:OUTPUT ACCEPT

# Uncomment next line to allow HTTP,HTTPS.
#-A INPUT -p tcp -m multiport --dports 80,443 -j ACCEPT

# Uncomment next line to allow SSH.
#-A INPUT -p tcp -m multiport --dports 22 -j ACCEPT

# Allow responses our outgoing transmissions.
-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

# Allow everything on loopback adapater.
-A INPUT -i lo -j ACCEPT

COMMIT
EOIPT
# -------------------------------------

cp "$iptables_file" "$ip6tables_file"
/etc/init.d/iptables-persistent restart
cd /etc && git add --all && commit_if_needed "$step mods"
ask_to_proceed "$step"


# FAIL2BAN ================================================

step="fail2ban"
step_header "$step"
apt-get -qq -y install fail2ban
cd /etc && git add --all && commit_if_needed "$step"

file=/etc/fail2ban/jail.conf
# Increase lockout length from 10 minutes to 1 day.
sed -r "s/^bantime\s+=.*/bantime = 86400/g" -i "$file"

ask_to_proceed "$step"


# SSHD ====================================================

step="sshd"
step_header "$step"
apt-get -qq -y install openssh-server openssh-blacklist openssh-blacklist-extra
cd /etc && git add --all && commit_if_needed "$step"

file=/etc/ssh/sshd_config
sed -r "s/^PermitRootLogin\s+(.*)/PermitRootLogin without-password/g" -i "$file"
commit_if_needed "$step mods"

service ssh reload
ask_to_proceed "$step"


# AUTOMATIC UPGRADES ======================================

step="automatic upgrades"
step_header "$step"

# Have unattended-upgrades run automatically.
file=/etc/apt/apt.conf.d/10periodic
set +e
grep -q "APT::Periodic::Unattended-Upgrade" "$file"
if [ $? -eq 0 ] ; then
    # Something is in there. Make sure it's enabled.
    set -e
    sed -r 's@^/*(\s*APT::Periodic::Unattended-Upgrade\s+)"[0-9]+"@\1"1"@g' -i "$file"
else
    # Nothing is in there. Add it.
    set -e
    echo 'APT::Periodic::Unattended-Upgrade "1";' >> "$file"
fi

# Clean the package cache every now and then.
set +e
grep -q "APT::Periodic::AutocleanInterval" "$file"
if [ $? -eq 0 ] ; then
    # Something is in there. Make sure it's enabled.
    set -e
    sed -r 's@^/*(\s*APT::Periodic::AutocleanInterval\s+)"[0-9]+"@\1"1"@g' -i "$file"
else
    # Nothing is in there. Add it.
    set -e
    echo 'APT::Periodic::AutocleanInterval "1"' >> "$file"
fi

# Alas, autoclean doesn't happen on it's own for some reason.
# Make a job that does the cleanup 10 minutes after the computer starts.
file=.uli_crontab
echo "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" > $file
echo "@reboot sleep 600 && apt-get -qq autoremove" >> $file
crontab $file
rm $file

# Uncomment all origins so all upgrades get installed automatically.
file=/etc/apt/apt.conf.d/50unattended-upgrades
sed -r 's@^/*(\s*"\$\{distro_id\}.*")@\1@g' -i "$file"

# Send an email listing packages upgraded or problems.
sed -E 's@^/*(\s*Unattended-Upgrade::Mail\s.*)@\1@g' -i "$file"

# Remove outdated packages and kernels to prevent drive from filling up.
sed -r 's@^/*(\s*Unattended-Upgrade::Remove-Unused-Dependencies\s+)"false"@\1"true"@g' -i "$file"

cd /etc && git add --all && commit_if_needed "$step"
ask_to_proceed "$step"


# DESIRED SOFTWARE ========================================

step="desired software"
step_header "$step"

echo ""
echo "During the next step, you'll be asked to set up Postfix."
echo "Pick 'Local only' from the list."
echo -n "Press ENTER to continue..."
read -e

file=/etc/apt/sources.list
sed -r "s/^# (deb.* partner)$/\1/g" -i "$file"
cd /etc && commit_if_needed "Allow 'partner' packages."

file=/etc/apt/sources.list.d/google-chrome.list
echo "deb http://dl.google.com/linux/chrome/deb/ stable main" > "$file"
sudo wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub \
    | sudo apt-key add -
cd /etc && git add --all && commit_if_needed "Add Google Chrome repository."

file=/etc/apt/sources.list.d/virtualbox.list
echo "deb http://download.virtualbox.org/virtualbox/debian trusty non-free" > "$file"
wget -q -O - http://download.virtualbox.org/virtualbox/debian/oracle_vbox.asc \
    | apt-key add -
cd /etc && git add --all && commit_if_needed "Add Virtualbox repository."

apt-get -qq update

apt-get -qq -y install \
    git-svn git-cvs gitk subversion subversion-tools cvs mercurial bzr \
    autoconf autoconf-doc autoconf2.13 automake1.4 re2c build-essential kcachegrind \
    libxml2-dev libbz2-dev libcurl4-openssl-dev libjpeg-dev libpng12-dev libmcrypt-dev unixodbc-dev libtidy-dev libxslt1-dev \
    konversation liferea skype mutt mb2md maildir-utils \
    links lynx google-chrome-stable curl icedtea-plugin w3m \
    mencoder mplayer mplayer-doc flashplugin-installer qt4-qtconfig \
    okular okular-extra-backends pdfposter pdftk poppler-utils \
    antiword tofrodos ack-grep gawk html2text uni2ascii tidy xz-utils \
    dictd dict-gcide dict-moby-thesaurus \
    apache2-doc apache2-mpm-prefork apache2-prefork-dev lighttpd memcached \
    mysql-client mysql-server sqlite sqlite-doc sqlite3 sqlite3-doc \
    virtualbox \
    ntp openvpn traceroute wireshark \
    gparted lm-sensors htop screen mcrypt \
    gnome-session-fallback gnome-panel gnome-themes-extras gnome-tweak-tool \
    gimp gimp-help-en imagemagick

# Packages not available in vivid (as of yet):
# myunity gnome-session-fallback

ln -s /usr/bin/ack-grep /usr/bin/ack

# Multimedia codecs and DVD playback.
apt-get -qq -y install ubuntu-restricted-extras
/usr/share/doc/libdvdread4/install-css.sh

cd /etc && git add --all && commit_if_needed "$step"
ask_to_proceed "$step"


# CTAGS AND GIT HOOKS =====================================

step="exuberant ctags and related git hooks"
step_header "$step"

source_dir=/usr/local/src
bin_dir=/usr/local/bin

# Install Exuberant Ctags from source.  5.8 has bugs.
mkdir -p "$source_dir"

cd "$source_dir"
svn checkout svn://svn.code.sf.net/p/ctags/code/trunk/ ctags
cd ctags
autoreconf
./configure
make
make install


# Ensure the template directory is there.
mkdir -p /usr/share/git-core/templates/hooks

# Put our hooks in Git's default template directory.
# Then, whenever git init or clone are called, these files get copied into the new
# repository's hooks directory.
cp "$repo_dir/git-hooks/"* /usr/share/git-core/templates/hooks

# Make calling "git ctags" execute our ctags script.
git config --system alias.ctags '!.git/hooks/ctags'


# Obtain and install my Ctags for SVN script.
cd "$source_dir"
git clone git://github.com/convissor/ctags_for_svn
ln -s "$source_dir/ctags_for_svn/ctags_for_svn.sh" "$bin_dir/ctags_for_svn.sh"


cd /etc && git add --all && commit_if_needed "$step"
ask_to_proceed "$step"


# BISON ===================================================
# PHP doesn't support compiling with Bison 3x,
# but Ubuntu 14.04+ ships with that.  Build bison from source.

cd "$source_dir"
wget https://ftp.gnu.org/gnu/bison/bison-2.7.tar.xz
tar xvJf bison-2.7.tar.xz
cd bison-2.7
./configure
make
make install


# USER INTERFACE TWEAKS ===================================

step="user interface tweaks"
step_header "$step"
file=/etc/lightdm/lightdm.conf

# Lightdm chokes if the section heading is not there
# https://bugs.launchpad.net/ubuntu/+source/lightdm/+bug/1164793
echo "[SeatDefaults]" > "$file"

# Need this to prevent "The system is running in low-graphics mode"
echo "greeter-session=unity-greeter" >> "$file"

# Don't give away user names to intruders.
echo "greeter-hide-users=true" >> "$file"

# Remove the guest session.
echo "allow-guest=false" >> "$file"

# Ditch the annoying new scroll bar format.
echo "export LIBOVERLAY_SCROLLBAR=0" >> /etc/X11/Xsession.d/80overlayscrollbars

# Kill the "ready sound"
cd /usr/share/glib-2.0/schemas
git init
git add --all
git commit -am 'Initial settings'
patch <<EOREADY
--- /usr/share/glib-2.0/schemas/com.canonical.unity-greeter.gschema.xml	2013-10-16 22:37:17.941475899 -0400
+++ /usr/share/glib-2.0/schemas/com.canonical.unity-greeter.gschema.xml	2013-10-16 22:35:42.092155086 -0400
@@ -79,7 +79,7 @@
       <summary>Whether to enable the screen reader</summary>
     </key>
     <key name="play-ready-sound" type="b">
-      <default>true</default>
+      <default>false</default>
       <summary>Whether to play sound when greeter is ready</summary>
     </key>
     <key name="indicators" type="as">
EOREADY
git commit -am 'Disable ready sound.'

cd /etc && git add --all && commit_if_needed "$step"
ask_to_proceed "$step"


# REGULAR USER ============================================

step="regular user"
step_header "$step"

loop_again=1
while [ $loop_again -eq 1 ] ; do
    echo -n "Creating regular user account.  Enter the LDAP user name for it:"
    read user

    if [ -z "$user" ] ; then
        echo "ERROR: Really, you need to do this..."
        loop_again=1
    else
        loop_again=0
    fi
done

adduser "$user"
adduser "$user" cdrom
adduser "$user" plugdev

if [ -d /root/.ssh ] ; then
    cp -R /root/.ssh "/home/$user"
    chown -R "$user":"$user" "/home/$user/.ssh"
    chmod 700 "/home/$user/.ssh"
    chmod 600 "/home/$user/.ssh"/*
fi

# Have root and admin user email alerts go to the regular user.
file=/etc/aliases
echo "root: $user" >> "$file"
echo "$admin_user: $user" >> "$file"
newaliases

cd /etc && git add --all && commit_if_needed "$step"
ask_to_proceed "$step"


# CLEAR OUT OLD PACKAGES ================================

step="clean out old packages"
step_header "$step"
apt-get -qq -y autoremove
cd /etc && git add --all && commit_if_needed "$step"
ask_to_proceed "$step"


# CHANGE REPOSITORY BACK ================================

echo "Ubuntu's software package servers have slow connections."
echo "To speed up the installation process, this script used faster servers."
echo "But to avoid you having problems in the future if the faster server"
echo "goes away, this next step will undo that change so your computer will"
echo "use Ubuntu's default server."
echo ""
echo -n "Okay? [Y|n]: "
read -e
if [[ -z "$REPLY" || "$REPLY" == y || "$REPLY" == Y ]] ; then
    step="set repository back to ubuntu's"
    step_header "$step"
    file=/etc/apt/sources.list
    sed "s/mirror\.pnl\.gov/us.archive.ubuntu.com/g" -i "$file"
    cd /etc && git add --all && commit_if_needed "$step"
    ask_to_proceed "$step"
fi


echo "That's all, folks!  Enjoy your new Ubuntu installation."
