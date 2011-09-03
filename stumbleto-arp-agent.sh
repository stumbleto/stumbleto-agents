#!/bin/bash
#
# Reads MAC Addresses from the arp table and submits them to stumble.to.
#
# (C) 2009 Ian Gallagher <crash@neg9.org>
#
# Depends on openssl-utils, libcurl, curl

api_key="YOUR_API_KEY"
api_secret="YOUR_API_SECRET"

service_url="http://stumble.to/api/update_ouis"
curl_flags="-s"
content_type="text/plain"
content_type="application/x-www-form-urlencoded"

# Set field seperator to newline
export IFS=$'\n'

if [ -r "/proc/net/arp" ]; then
	# OS Is probably linux
	oui_list=$(grep '..:..:..:..:..:..' < /proc/net/arp | grep -v -i '..:ff:ff:ff:ff:ff' | awk '{print $4}')
else
	# OS is probably a BSD
	oui_list=$(arp -an | grep '..:..:..:..:..:..' | grep -v -i '..:ff:ff:ff:ff:ff' | awk '{print $4}')
fi

unset IFS

data='{'
item=""

for oui in $oui_list; do
	if [ $(echo -n $oui | wc -c) != "17" ]; then
		oui="0${oui}"
	fi
	item="\"$oui\": 0"
	if [ ${#data} -eq 1 ]; then
		data="${data}${item}"
	else
		data="${data}, $item"
	fi
done

data="${data}}"

# Sign the data (SHA512 HMAC)
hmac=$(echo -n ${data} | openssl dgst -sha512 -hmac ${api_secret})

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
