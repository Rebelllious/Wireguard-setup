#!/bin/bash

# Sample script installing the Wireguard VPN server and configuring one mobile client

CENTOS7="centos:centos:7"
ROCKY8="rocky:rocky:8"
ALMA8="almalinux:almalinux:8"
ORACLE7="oracle:linux:7"
ORACLE8="oracle:linux:8"

ALLOWED_IPS_CLIENT="0.0.0.0/0"

# subnet for VPN clients' IPs. Adjust only if know what you are doing
VPN_SERVER_MASK="24"

echo -e "\e[32mSetting up prerequisites\e[0m"
yum install bind-utils -y

echo -e "\e[32mYour VPN server's (public) IP or FQDN:\e[0m"
read PUBLIC_VPN_ADDRESS
# check if this is a well-formed IP or FQDN
# below condition checks the address and if it is not a well-formed IP, it checks if it is an FQDN
while ! [[ "$PUBLIC_VPN_ADDRESS" =~ ^(([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){3}([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))$ ]]
do
    nslookup $PUBLIC_VPN_ADDRESS 2>&1 > /dev/null
    if [[ $? -ne 0 ]]
    then
    	echo -e "\e[31mMalformed IP or FQDN. Enter it right this time:\e[0m"
    	read PUBLIC_VPN_ADDRESS
    else
    	break
    fi
done

echo -e "\e[32mYour VPN server's UDP port to be used (between 1024 and 65535):\e[0m"
read PUBLIC_VPN_PORT
while ! [[ "$PUBLIC_VPN_PORT" =~ ^[0-9]+$ ]] || [[ "$PUBLIC_VPN_PORT" -lt "1025" ]] || [[ "$PUBLIC_VPN_PORT" -gt "65535" ]]
do
	if ! [[ "$PUBLIC_VPN_PORT" =~ ^[0-9]+$ ]]
	then
		echo -e "\e[31mPort shall contain digits only. Selection range is 1025-65535. Try again:\e[0m"
	elif [[ "$PUBLIC_VPN_PORT" -lt "1025" ]] || [[ "$PUBLIC_VPN_PORT" -gt "65535" ]]
	then
		echo -e "\e[31mSelection range is 1025-65535. Try again:\e[0m"
	fi
	read PUBLIC_VPN_PORT
done

IP_VALID="false"

echo -e "\e[32mType WireGuard VPN server internal IP (10.*.*.1, 172.16.*.1-172.31.*.1, 192.168.*.1):\e[0m"

while ! [ "$IP_VALID" = "true" ]
  do
  read VPN_SERVER_IP
  # Check if we have correct number of octets
  if ! [[ "$VPN_SERVER_IP" =~ ^(([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){3}([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))$ ]]
  then
    echo -e '\e[31mMalformed IP detected. Try again:\e[0m'
    continue
  fi
  # Check if IP ends with 1
  if [[ $(cut -d . -f 4 <<< $VPN_SERVER_IP) -ne "1" ]]
  then
    echo -e '\e[31mIP does not end with "1". Try again:\e[0m'
    continue
  fi
  # Check if it's private IP
  grep -E -q '^(192\.168|10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.)' <<< $VPN_SERVER_IP
  if [[ $? -ne 0 ]]
  then
    echo -e "\e[31mIP you entered is not a private IP. Try again:\e[0m"
    continue
  fi

  IP_VALID="true"

done


echo -e "\e[32mDNS server IP for clients, comma separated \e[0m(e.g.: \"1.1.1.1,8.8.8.8\")\e[32m
* Local & public, or local only, if FQDNs behind VPN need to be resolved;
* Public only, if there is no need for resolving local FQDNs\e[0m"
read DNS
IFS=","
for i in "${DNS[@]}"
do
	if ! [[ $i =~ ^(([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){3}([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))$ ]]
	then
		echo -e "\e[31mMalformed IP or FQDN. Enter it right this time:\e[0m"
    	read DNS
  fi
done


centos7 () {
  echo -e "\n\e[32mRunning installation steps for CentOS 7\e[0m\n"
	yum install epel-release https://www.elrepo.org/elrepo-release-7.el7.elrepo.noarch.rpm -y
	yum install yum-plugin-elrepo	-y
}

ol7 () {
  echo -e "\n\e[32mRunning installation steps for Oracle Linux 7\e[0m\n"
	yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm https://www.elrepo.org/elrepo-release-7.el7.elrepo.noarch.rpm -y
	yum install http://mirror.centos.org/centos/7/os/x86_64/Packages/qrencode-3.4.1-3.el7.x86_64.rpm -y
}

ol8 () {
  echo -e "\n\e[32mRunning installation steps for Oracle Linux 8\e[0m\n"
  yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm https://www.elrepo.org/elrepo-release-8.el8.elrepo.noarch.rpm -y
}

alma8 () {
  echo -e "\n\e[32mRunning installation steps for Alma Linux 8\e[0m\n"
}

rocky8 () {
  echo -e "\n\e[32mRunning installation steps for Rocky Linux 8\e[0m\n"
  yum install elrepo-release epel-release -y
}

rh_eight () {
	echo -e "\n\e[32mRunning installation steps for RH family 8\n"
	yum install elrepo-release epel-release -y
}

OS=$(hostnamectl | grep "CPE OS Name")
if [[ "$OS" == *"$CENTOS7"* ]]
then
  centos7
elif [[ "$OS" == *"$ORACLE7"* ]]
then
  ol7
elif [[ "$OS" == *"$ORACLE8"* ]]
then
	ol8
elif [[ "$OS" == *"$ROCKY8"* ]] || [[ "$OS" == *"$ALMA8"* ]]
then
  rh_eight
fi


echo -e "\n\e[32mInstalling OS updates\e[0m\n"
yum update -y
echo -e "\e[32mInstalling Wireguard\e[0m"
yum install kmod-wireguard wireguard-tools -y
if [[ "$OS" == "$ORACLE7" ]]
then
  yum install http://mirror.centos.org/centos/7/os/x86_64/Packages/qrencode-3.4.1-3.el7.x86_64.rpm -y
else
	yum install qrencode -y
fi

echo -e "\n\e[32mSetting up packet forwarding\e[0m\n"
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p 1 > /dev/null

echo -e "\n\e[32mSetting up firewall\e[0m\n"
firewall-cmd --zone=public --permanent --add-masquerade > /dev/null
firewall-cmd --permanent --add-port=$PUBLIC_VPN_PORT/udp > /dev/null
systemctl reload firewalld 1 > /dev/null

echo -e "\n\e[32mConfiguring Wireguard\e[0m\n"
mkdir -p /etc/wireguard/
cd /etc/wireguard
echo -e "\n\e[32mGenerating server keys\e[0m\n"
wg genkey | tee server_private.key | wg pubkey | tee server_public.key 1 > /dev/null
echo -e "\n\e[32mGenerating client keys\e[0m\n"
wg genkey | tee phone_private.key | wg pubkey | tee phone_public.key 1 > /dev/null

SERVER_PRIVATE=$(cat server_private.key)
SERVER_PUBLIC=$(cat server_public.key)
PHONE_PRIVATE=$(cat phone_private.key)
PHONE_PUBLIC=$(cat phone_public.key)

echo -e "\n\e[32mCreating server's config file\e[0m\n"
echo "[Interface]
Address = $VPN_SERVER_IP/$VPN_SERVER_MASK
SaveConfig = true
PrivateKey = $SERVER_PRIVATE
ListenPort = $PUBLIC_VPN_PORT

[Peer]
PublicKey = $PHONE_PUBLIC
AllowedIPs = $(echo $VPN_SERVER_IP | cut -d"." -f1-3).2/32
" > /etc/wireguard/wg0.conf

echo -e "\n\e[32mCreating client's config file\e[0m\n"
echo "[Interface]
PrivateKey = $PHONE_PRIVATE
Address = $(echo $VPN_SERVER_IP | cut -d"." -f1-3).2/32
DNS = $DNS

[Peer]
PublicKey = $SERVER_PUBLIC
Endpoint = $PUBLIC_VPN_ADDRESS:$PUBLIC_VPN_PORT
AllowedIPs = $ALLOWED_IPS_CLIENT
" > /etc/wireguard/phone.conf

chmod -R 600 /etc/wireguard/

echo -e "\n\e[32mEnabling autostart for Wireguard\e[0m\n"
systemctl enable wg-quick@wg0
echo -e "\n\e[32mStarting Wireguard\e[0m\n"
systemctl start wg-quick@wg0

qrencode -t utf8 < /etc/wireguard/phone.conf
echo -e "\n\e[32mOpen Wireguard on your phone and scan the above QR code to set up the connection\e[0m"
