#!/bin/bash
#
# Submits new DHCP leases from dnsmasq to stumble.to. 
# Set this script as the dhcp-script in your dnsmasq config.
#
# Authors:
#   Eric Butler <eric@codebutler.com>
#   Ian Gallagher <crash@neg9.org>
#
# Depends on openssl-utils, libcurl, curl

# Update these values:
api_key="YOUR_API_KEY"
api_secret="YOUR_API_SECRET"

service_url="http://stumble.to/api/update"
curl_flags="-s"
content_type="text/plain"
content_type="application/x-www-form-urlencoded"

# Based on https://gist.github.com/1163649
_encode() {
  local _length="${#1}"
  _length=$(expr $_length - 1)
  for _offset in $(seq 0 $_length); do
    _print_offset="${1:$_offset:1}"
    case "${_print_offset}" in
      [a-zA-Z0-9.~_-]) printf "${_print_offset}" ;;
      ' ') printf + ;;
      *) printf '%%%X' "'${_print_offset}" ;;
    esac
  done
}

action=$1
mac=$2
host=$3

if [ $action != "add" ]; then
  exit 0
fi

devices="[ { \"identifier\": \"$mac\", \"type\": \"wifi\" } ]"

data="api_key=$api_key&devices=$(_encode "${devices}")"
signature=$(echo -n ${data} | openssl dgst -sha512 -hmac ${api_secret})
data="$data&signature=$signature"

# Post the data to the web service
http_response=$(curl $curl_flags -H "Content-Type: ${content_type}" --data "${data}" $service_url 2>/dev/null)

# Check to see if the webservice call succeeded
echo $http_response | grep -q -i -e "success.*success"

if [ $? -eq 0 ]; then
  # Success! Return 0
  exit 0
else
  # Failure, return 1
  exit 1
fi
