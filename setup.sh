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
    if [ ! -d "$dir" ] ; then
        echo "~/.ssh found.  Skipping SSH key generation."
    fi
    chmod 700 /root/.ssh
fi

chmod 600 /root/.ssh/*

ask_to_proceed "$step"


# TRACK ALL CONFIGURATION CHANGES =========================

step="git"
step_header "$step"
apt-get -qq -y install git-core git-doc
cd /etc
git init
chmod 770 .git

git config --global user.name root
git config --global user.email root@localhost

echo "mtab" >> .gitignore
echo "cups/subscriptions*" >> .gitignore
git add --all
commit_if_needed "$step"

ask_to_proceed "$step"


# USE EU REPOSITORIES =====================================
# The default us. repositories are VERRRRRRRRRY slow (eg 150 KB/s)

step="use anl.gov repository instead of ubuntu's"
step_header "$step"
file=/etc/apt/sources.list
sed -E "s/us\.archive\.ubuntu\.com/mirror.anl.gov/g" -i "$file"
cd /etc && git add --all && commit_if_needed "$step"
ask_to_proceed "$step"


# SOFTWARE UPGRADE ========================================

step="upgrade"
step_header "$step"
apt-get -qq update && apt-get -qq -y upgrade
cd /etc && git add --all && commit_if_needed "$step mods"
ask_to_proceed "$step"


# MAKE GRUB USABLE ========================================

step="grub fixup"
step_header "$step"
file=/etc/default/grub
# Get grub menu to show by commenting out this option.
sed -E "s/(GRUB_HIDDEN_TIMEOUT.*)/#\1/g" -i "$file"
# Shorten timeout to 5 seconds.
sed -E "s/(GRUB_TIMEOUT=.*)$/GRUB_TIMEOUT=5/g" -i "$file"

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

# Allow HTTP,HTTPS.
#-A INPUT -p tcp -m multiport --dports 80,443 -j ACCEPT

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
sed -E "s/^bantime\s+=.*/bantime = 86400/g" -i "$file"

ask_to_proceed "$step"


# SSHD ====================================================

step="sshd"
step_header "$step"
apt-get install -qq -y openssh-server openssh-blacklist openssh-blacklist-extra
cd /etc && git add --all && commit_if_needed "$step"

file=/etc/ssh/sshd_config
sed -E "s/^PermitRootLogin\s+(.*)/PermitRootLogin without-password/g" -i "$file"
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
    sed -E 's@^/*(\s*APT::Periodic::Unattended-Upgrade\s+)"[0-9]+"@\1"1"@g' -i "$file"
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
    sed -E 's@^/*(\s*APT::Periodic::AutocleanInterval\s+)"[0-9]+"@\1"14"@g' -i "$file"
else
    # Nothing is in there. Add it.
    set -e
    echo 'APT::Periodic::AutocleanInterval "14"' >> "$file"
fi

# Uncomment all origins so all upgrades get installed automatically.
file=/etc/apt/apt.conf.d/50unattended-upgrades
sed -E 's@^/*(\s*"\$\{distro_id\}.*")@\1@g' -i "$file"

# Remove outdated packages and kernels to prevent drive from filling up.
sed -E 's@^/*(\s*Unattended-Upgrade::Remove-Unused-Dependencies\s+)"false"@\1"true"@g' -i "$file"

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
sed -E "s/^# (deb.* partner)$/\1/g" -i "$file"
cd /etc && commit_if_needed "Allow 'partner' packages."

file=/etc/apt/sources.list.d/google-chrome.list
echo "deb http://dl.google.com/linux/chrome/deb/ stable main" > "$file"
sudo wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub \
    | sudo apt-key add -
cd /etc && git add --all && commit_if_needed "Add Google Chrome repository."

apt-get -qq update

apt-get -qq -y install \
    git-svn git-cvs gitk subversion subversion-tools cvs mercurial \
    konversation skype mutt links lynx google-chrome-stable curl \
    flashplugin-installer qt4-qtconfig \
    vim exuberant-ctags \
    okular okular-extra-backends poppler-utils \
    antiword tofrodos ack-grep gawk \
    sqlite3 sqlite3-doc \
    ntp traceroute gparted lm-sensors htop screen \
    gnome-session-fallback gnome-panel gnome-tweak-tool \
    gimp gimp-help-en

# Packages not available in trusty (as of yet):
# epdfview pdfedit myunity

ln -s /usr/bin/ack-grep /usr/bin/ack

# Multimedia codecs and DVD playback.
apt-get -qq -y install ubuntu-restricted-extras
/usr/share/doc/libdvdread4/install-css.sh

cd /etc && git add --all && commit_if_needed "$step"
ask_to_proceed "$step"


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


# VIM SETTINGS ========================================

echo -n "Should we give each user Dan's vim settings? [N|y]: "
read -e
if [[ "$REPLY" == y || "$REPLY" == Y ]] ; then
    cd
    git clone git://github.com/convissor/vim-settings.git
    cd vim-settings
    ./setup.sh

    dirs=`ls /home`

    for dir in $dirs ; do
        cd "/home/$dir"
        cp -R /root/vim-settings .
        cd vim-settings
        ./setup.sh
        cd ..
        chown -R "$dir":"$dir" .vim .vimrc vim-settings
    done
fi

ask_to_proceed "$step"


# CLEAR OUT OLD PACKAGES ================================

step="clean out old packages"
step_header "$step"
apt-get -qq -y autoremove
cd /etc && git add --all && commit_if_needed "$step"
ask_to_proceed "$step"


# KERNEL UPGRADE ========================================

step="kernel upgrade"
step_header "$step"
apt-get -qq -y dist-upgrade
cd /etc && git add --all && commit_if_needed "$step mods"
if [ -a /var/run/reboot-required ] ; then
    echo "REBOOT IS REQURED"
    echo -n "Press ENTER to continue..."
    read -e
    shutdown -r now
    exit
fi
ask_to_proceed "$step"

echo "That's all, folks!  Enjoy your new Ubuntu installation."
