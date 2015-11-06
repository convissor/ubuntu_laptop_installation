#! /bin/bash -e

if [[ $1 == "-h" || $1 == "--help" || $1 == "help" ]] ; then
    echo "Usage: duckduckgo-html-search.sh"
    echo ""
    echo "Changes DuckDuckGo search URL to work with JavaScript disabled."
    echo ""
    echo "Author: Daniel Convissor <danielc@analysisandsolutions.com>"
    echo "https://github.com/convissor/ubuntu_laptop_installation"
    exit 1
fi


for search_file in $(find ~/.mozilla/firefox -name search.json) ; do
    sed 's@https://duckduckgo.com/"@https://duckduckgo.com/html/"@' -i "$search_file"
    echo "$search_file"
done
