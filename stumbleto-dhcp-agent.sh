#!/bin/sh
#
# Reads MAC Addresses from the DHCP lease table and submits them to stumble.to.
#
# (C) 2009 Ian Gallagher <crash@neg9.org>
#
# Depends on openssl-utils, libcurl, curl, dnsmasq

service_url="http://stumble.to/api/update_ouis"
curl_flags="-s"
content_type="text/plain"
content_type="application/x-www-form-urlencoded"
api_key="32_CHARACTER_KEY_FROM_VENUE_PAGE"
api_secret="32_CHARACTER_SECRET_FROM_VENUE_PAGE"

# dnsmasq DHCP leases file (default is OpenWRT's path to it)
leases_file="/tmp/dhcp.leases"

# Set field seperator to newline
export IFS=$'\n'

data='{'
item=""
for lease in $(cat ${leases_file}); do
	item=$(echo -n $lease | \
	awk '{print "\"" $2 "\":", $1}' | tr -d '\n')
	if [ ${#data} -eq 1 ]; then
		data="${data}${item}"
	else
		data="${data}, $item"
	fi
done

data="${data}}"

# Sign the data (SHA512 HMAC)
hmac=$(echo -n "${data}" | openssl dgst -sha512 -hmac "${api_secret}")

# Construct the message (data, api key, signature)
msg="${data}"$'\n'"${api_key}"$'\n'"${hmac}"

# Post the data to the web service
http_response=$(curl $curl_flags -H "Content-Type: ${content_type}" --data "${msg}" $service_url 2>/dev/null)

# Check to see if the webservice call succeeded
echo $http_response | grep -q -i -e "success.*true"

if [ $? -eq 0 ]; then
	# Success! Return 0
	exit 0
else
	# Failure, return 1
	exit 1
fi
