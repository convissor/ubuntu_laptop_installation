#! /bin/bash -e

if [[ $1 == "-h" || $1 == "--help" || $1 == "help" ]] ; then
    echo "Usage: livehttpheaders-color-fix.sh"
    echo ""
    echo "Removes font colors from Live HTTP Headers' output."
    echo ""
    echo "Author: Daniel Convissor <danielc@analysisandsolutions.com>"
    echo "https://github.com/convissor/ubuntu_laptop_installation"
    exit 1
fi

trap "rm -rf /tmp/livehttpheaders" EXIT

for jar_file in $(find ~/.mozilla/firefox -name livehttpheaders.jar) ; do
    rm -rf /tmp/livehttpheaders
    mkdir /tmp/livehttpheaders
    unzip -q "$jar_file" -d /tmp/livehttpheaders
    cd /tmp/livehttpheaders
    sed 's@^\s*color: #000000;@/* color: #000000; Remove to ensure contrast. --convissor */@' -i "skin/livehttpheaders.css"
    zip -rq livehttpheaders.jar content/ locale/ skin/
    cp livehttpheaders.jar "$jar_file"
    cd
done
