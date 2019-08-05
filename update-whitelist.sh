#!/bin/bash

echo -e "This script will download and update domains into the DNS whitelist zone."
sleep 0.1

if [ "$(id -u)" != "0" ] ; then
	echo "This script requires root permissions. Please run this as root!"
	exit 2
fi

echo "Downloading updated whitelist..."
curl -# -L "https://raw.githubusercontent.com/anudeepND/whitelist/master/domains/whitelist.txt" \
	| sed 's/$/ CNAME rpz-passthru./g' > /tmp/whitelist.list

echo "Merging with the current database..."
cp /etc/bind/db.rpz.whitelist /tmp/current.list
cat /tmp/whitelist.list | tee -a /tmp/current.list > /dev/null
cat /tmp/current.list \
	| tail -n+3 \
	| sort \
	| uniq --ignore-case > /tmp/updated.list

echo "Updating zone serial..."
awk '{ if ( $0 ~ /[\t ]SOA[\t ]/ ) $7=$7+1; print}' /usr/local/bin/whitelist-zone.header > /usr/local/bin/whitelist-zone.header.new
mv /usr/local/bin/whitelist-zone.header.new /usr/local/bin/whitelist-zone.header
cp /usr/local/bin/whitelist-zone.header /etc/bind/db.rpz.whitelist
cat /tmp/updated.list | tee -a /etc/bind/db.rpz.whitelist > /dev/null

echo "Echo checking if bind9 configuration has been broken..."
named-checkconf

echo "Cleaning up..."
rm /tmp/*.list

echo "Done!"
echo "Use 'rndc reload' command to reload the zone."
