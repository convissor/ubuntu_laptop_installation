#! /bin/bash -e

if [[ $1 == "-h" || $1 == "--help" || $1 == "help" ]] ; then
    echo "Usage: netflix-desktop.sh"
    echo ""
    echo "Installs the Netflix Desktop program."
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


# ENSURE ALL SOFTWARE IS UP TO DATE =====================

step="upgrade installed software"
step_header "$step"
apt-get -qq update && apt-get -qq -y upgrade
cd /etc && git add --all && commit_if_needed "$step mods"
ask_to_proceed "$step"


# ENSURE KERNEL IS THE LATEST ===========================

step="kernel upgrade"
step_header "$step"
apt-get -qq -y dist-upgrade
cd /etc && git add --all && commit_if_needed "$step mods"
if [ -a /var/run/reboot-required ] ; then
    echo "REBOOT IS REQURED"
    echo ""
    echo "We just installed the latest kernel available."
    echo "Before installing netflix-desktop, a restart is required."
    echo "After reboot, run this netflix-desktop.sh script again."
    echo ""
    echo -n "Press ENTER to continue..."
    read -e
    shutdown -r now
    exit
fi
ask_to_proceed "$step"


# NETFLIX DESKTOP =======================================

step="netflix desktop"
step_header "$step"

apt-add-repository -y ppa:ehoover/compholio
apt-get -qq update
apt-get -qq -y install netflix-desktop
cd /etc && git add --all && commit_if_needed "$step"
ask_to_proceed "$step"


# THE END ===============================================
echo "Fini!"
echo ""
echo "Now log out of your admin account."
echo ""
echo "Then log in to your regular user account and run:"
echo "    ALT-F1, Enter, Type 'netflix', Enter"
echo ""
echo "Follow the Wine Mono and Wine Gecko install instructions that appear."
echo ""
echo "You can disregard error messages like the following:"
echo "    Unexpected checksum of downloaded file."
echo "    Aborting installation of corrupted file."
echo ""
echo "Once Netflix Desktop is running, you can hit F11 to exit full screen."
echo "(Handy when the X in the top right corner blocks the 'Sign in' button.)"
echo ""
echo "Enjoy!"