#!/bin/bash
#
# Startup mosh connect over proxy

user=
host=
port=
: ${proxy_type:="socks5"}
proxy=

# Check proxy type is available
is_valid_proxy_type() {
  [[ "$1" = 'http' || "$1" = 'socks4' || "$1" = 'socks5' ]]
  return $?
}

usage() {
  echo "Usage: $(basename $0) [-u USER] -h HOST [-p PORT] [-X PROXY_TYPE] -x PROXY_HOST:PORT"
  echo "-u login user, default: current user"
  echo "-p server ssh port, default: 22"
  echo "-X proxy type, default: socks5, available value 'socks5, socks4, http'"
}

gen_proxy_command() {
  local openbsd=$(nc -h 2>&1 | grep "\\-X")
  local gun=$(nc -h 2>&1 | grep "\\--proxy-type")
  local local_proxy_type

  if [ -n "$openbsd" ]; then
    case $proxy_type in
      http) local_proxy_type="connect" ;;
      socks4) local_proxy_type="4" ;;
      socks5) local_proxy_type="5" ;;
    esac
    echo "nc -x $proxy -X $local_proxy_type %h %p"
  elif [ -n "$gun" ]; then
    case $proxy_type in
      http) local_proxy_type="http" ;;
      socks4) local_proxy_type="socks4" ;;
      socks5) local_proxy_type="socks5" ;;
    esac
    echo "nc --proxy $proxy --proxy-type $local_proxy_type %h %p"
  else
    echo "Unknown netcat flavor!"
    exit 1
  fi
}

while getopts "u:h:p:X:x:" OPT; do
  case $OPT in
    u) user=$OPTARG ;;
    h) host=$OPTARG ;;
    p) port=$OPTARG ;;
    X) proxy_type=$OPTARG ;;
    x) proxy=$OPTARG ;;
  esac
done

# Check paramaters
if [[ -z "$host" || -z "$proxy" ]]; then
  usage
  exit 1
fi

if ! is_valid_proxy_type $proxy_type; then
  usage
  exit 1
fi

proxy_command=$(gen_proxy_command)

if [ -n "$user" ]; then
  host_str="${user}@${host}"
else
  host_str="$host"
fi

mosh_data=$(ssh -t -o ProxyCommand="$proxy_command" $host_str mosh-server new | grep '^MOSH' | tr -d '\r\n')

mosh_port="$(echo -n "$mosh_data" | cut -s -d' ' -f3)"
mosh_key="$(echo -n "$mosh_data" | cut -s -d' ' -f4)"

if [[ -z "$mosh_port" || -z "$mosh_key" ]]; then
  echo "Got something wrong!"
  echo $mosh_data
  exit 1
fi

MOSH_KEY="$mosh_key" exec mosh-client "$host" "$mosh_port"

