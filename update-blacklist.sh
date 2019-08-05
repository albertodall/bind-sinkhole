#!/bin/bash

PIXELSERV_IP="192.168.10.2"

echo -e "This script will download and update domains into the DNS blacklist zone."
sleep 0.1

if [ "$(id -u)" != "0" ] ; then
	echo "This script requires root permissions. Please run this as root!"
	exit 2
fi

echo "Downloading pgl.yoyo.org list..."
curl -# "http://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=0&mimetype=plaintext" \
	| sed -e '/^#/d' -e '/_/d' -e '/</d' \
	| awk NF \
	| sed 's/^127.0.0.1 //g' \
        | sed "s/\$/ IN A ${PIXELSERV_IP}/g" > /tmp/pgl-yoyo-org.list

echo "Downloading StevenBlack list..."
curl -# "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts" \
	| sed 's/#.*$//g' \
	| awk NF \
	| sed '/_/d' \
	| sed 1,14d \
	| sed 's/^0.0.0.0 //g' \
	| sed "s/\$/ IN A ${PIXELSERV_IP}/g" > /tmp/stevenblack.list

echo "Downloading malwaredomains list...."
curl -# -L "http://mirror1.malwaredomains.com/files/spywaredomains.zones" \
	| sed -e '/\/\//d' -e '/_/d' -e '/</d' \
	| awk NF \
	| sed 's/^zone "//g' | sed 's/"  {.*$//g' \
	| sed "s/\$/ IN A ${PIXELSERV_IP}/g" > /tmp/malwaredomains.list

echo "Downloading ZeusTracker list..."
curl -# "https://zeustracker.abuse.ch/blocklist.php?download=domainblocklist" \
	| sed -e '/^#/d' -e '/_/d' -e '/</d' \
	| awk NF \
	| sed "s/\$/ IN A ${PIXELSERV_IP}/g" > /tmp/zeustracker.list

echo "Downloading Cameleon host list..."
curl -# "http://sysctl.org/cameleon/hosts" \
	| sed -e '/_/d' -e '/</d' \
	| sed 1,2d \
	| awk NF \
	| sed 's/127.0.0.1\t //g' \
	| sed 's/$/ IN A 192.168.10.2/g' > /tmp/cameleon.list

echo "Downloading Disconnect.me tracking list..."
curl -# "https://s3.amazonaws.com/lists.disconnect.me/simple_tracking.txt " \
	| awk NF \
	| sed -e '/#/d' -e '/_/d' -e '/</d' \
	| sed "s/\$/ IN A ${PIXELSERV_IP}/g" > /tmp/disconnectme_tracking.list

echo "Downloading Disconnect.me ads list..."
curl -# "https://s3.amazonaws.com/lists.disconnect.me/simple_ad.txt " \
        | awk NF \
        | sed -e '/#/d' -e '/_/d' -e '/</d'  \
        | sed "s/\$/ IN A ${PIXELSERV_IP}/g" > /tmp/disconnectme_ad.list

echo "Downloading hosts-file.net list..."
curl -# "https://hosts-file.net/ad_servers.txt" \
	| sed -e '/^#/d' -e '/_/d' -e '/</d' \
	| sed 1,2d \
	| sed 's/^127.0.0.1\t//g' \
	| tr -d '\r' \
	| sed "s/\$/ IN A ${PIXELSERV_IP}/g" > /tmp/hostsfile.list

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
mv /tmp/db.rpz.blacklist /etc/bind/db.rpz.blacklist

echo "Checking if bind9 configuration has been broken..."
named-checkconf

echo "Cleaning up..."
rm /tmp/*.list

echo "Done!"
echo "Use 'rndc reload' command to reload the zone."
