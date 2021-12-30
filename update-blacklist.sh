#!/bin/bash

PIXELSERV_IP="<YOUR_PIXELSERV_IP_ADDRESS>"

echo -e "This script will download and update domains into the DNS blacklist zone."
sleep 0.1

if [ "$(id -u)" != "0" ] ; then
        echo "This script requires root permissions. Please run this as root!"
        exit 2
fi

echo "Downloading StevenBlack list..."
curl -# "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts" \
        | sed 's/#.*$//g' \
        | awk NF \
        | sed '/_/d' \
        | sed 1,14d \
        | sed 's/^0.0.0.0 //g' \
        | sed "s/\$/ IN A ${PIXELSERV_IP}/g" > /tmp/stevenblack.list

echo "Downloading Phishing Army list..."
curl -# "https://phishing.army/download/phishing_army_blocklist.txt" \
        | awk NF \
        | sed -e '/^#/d' \
        | sed "s/\$/ IN A ${PIXELSERV_IP}/g" > /tmp/phishingarmy.list

echo "Downloading Cameleon host list..."
curl -# "http://sysctl.org/cameleon/hosts" \
        | sed -e '/_/d' -e '/</d' \
        | sed 1,2d \
        | awk NF \
        | sed 's/127.0.0.1\t //g' \
        | sed "s/$/ IN A ${PIXELSERV_IP}/g" > /tmp/cameleon.list

echo "Downloading Disconnect.me tracking list..."
curl -# "https://s3.amazonaws.com/lists.disconnect.me/simple_tracking.txt" \
        | awk NF \
        | sed -e '/#/d' -e '/_/d' -e '/</d' \
        | sed "s/\$/ IN A ${PIXELSERV_IP}/g" > /tmp/disconnectme_tracking.list

echo "Downloading Disconnect.me ads list..."
curl -# "https://s3.amazonaws.com/lists.disconnect.me/simple_ad.txt" \
        | awk NF \
        | sed -e '/#/d' -e '/_/d' -e '/</d'  \
        | sed "s/\$/ IN A ${PIXELSERV_IP}/g" > /tmp/disconnectme_ad.list

echo "Downloading YouTube ads list..."
curl -# "https://jasonhill.co.uk/pfsense/ytadblock.txt" \
        | awk NF \
        | sed -e '/^#/d' \
        | sed -n '/googlevideo/p' \
        | sed "s/\$/ IN A ${PIXELSERV_IP}/g" > /tmp/ytads.list

echo "Merging all together and creating the new database..."
sort /tmp/*.list | uniq --ignore-case > /tmp/db.rpz.blacklist

echo "Updating zone serial..."
awk '{ if ( $0 ~ /[\t ]SOA[\t ]/ ) $7=$7+1; print}' /usr/local/bin/blacklist-zone.header > /usr/local/bin/blacklist-zone.header.new
mv /usr/local/bin/blacklist-zone.header.new /usr/local/bin/blacklist-zone.header
cat /usr/local/bin/blacklist-zone.header /tmp/db.rpz.blacklist | sponge /tmp/db.rpz.blacklist

echo "Moving generated database to Bind configuration folder..."
mv /tmp/db.rpz.blacklist /etc/bind/zones/db.rpz.blacklist

echo "Checking if bind9 configuration has been broken..."
named-checkconf

echo "Cleaning up..."
rm /tmp/*.list

echo "Done!"
echo "Use 'rndc reload' command to reload the zone."
