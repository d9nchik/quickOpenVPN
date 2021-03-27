#!/bin/bash

# Variables to configure script
myUser="ubuntu"
country="US"
province="NewYork"
city="New York City"
organization="d9nchik"
email="admin@example.com"
ou="Community"
$caPassword="qawsxedc"
$nameOfServer="server"

# Run from root

myPath=`pwd`


# Installing updates
apt update
apt upgrade
apt -y install easy-rsa expect openvpn

su $myUser


mkdir ~/easy-rsa
ln -s /usr/share/easy-rsa/* ~/easy-rsa/
chmod 700 /home/$myUser/easy-rsa
cd ~/easy-rsa
./easyrsa init-pki

cd ~/easy-rsa
echo "set_var EASYRSA_REQ_COUNTRY    $country
set_var EASYRSA_REQ_PROVINCE   $province
set_var EASYRSA_REQ_CITY       $city
set_var EASYRSA_REQ_ORG        $organization
set_var EASYRSA_REQ_EMAIL      $email
set_var EASYRSA_REQ_OU         $ou
set_var EASYRSA_ALGO           "ec"
set_var EASYRSA_DIGEST         "sha512"" > vars

./$myPath/utilities/createCA.exp $organization $caPassword

./$myPath/utilities/createSereverCertificate.exp $nameOfServer

exit

cp /home/$myUser/easy-rsa/pki/private/server.key /etc/openvpn/server/

su $myUser
cd ~/easy-rsa
./sign $nameOfServer

# change executing directory

./$myPath/utilities/signCertificate.exp $nameOfServer $caPassword server

exit

cp /home/$myUser/easy-rsa/pki/issued/server.crt /home/$myUser/pki/ca.crt /etc/openvpn/server

su $myUser

cd ~/easy-rsa
openvpn --genkey --secret ta.key
exit
sudo cp /home/$myUser/easy-rsa/ta.key /etc/openvpn/server
su $myUser
mkdir -p ~/client-configs/keys
chmod -R 700 ~/client-configs

cd ~/easy-rsa
./createClientCertificate client1
cp pki/private/client1.key ~/client-configs/keys/

./$myPath/utilities/signCertificate.exp client1 $caPassword client

cp pki/issued/client1.crt ~/client-configs/keys/
cp ~/easy-rsa/ta.key ~/client-configs/keys/
exit
cp /etc/openvpn/server/ca.crt /home/$myUser/client-configs/keys/
chown $myUser.$myUser /home/$myUser/client-configs/keys/*

cp /usr/share/doc/openvpn/examples/sample-config-files/server.conf.gz /etc/openvpn/server/
gunzip /etc/openvpn/server/server.conf.gz

# cahnge to real path
cp $myPath/utilities/utilities/server.conf /etc/openvpn/server/server.conf
echo "
net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p
deafultInterface=`ip r | awk '/^default/ {print $5}'`
sed -i '1i# START OPENVPN RULES
# NAT table rules
*nat
:POSTROUTING ACCEPT [0:0]
# Allow traffic from OpenVPN client to $deafultInterface (change to the interface you discovered!)
-A POSTROUTING -s 10.8.0.0/8 -o $deafultInterface -j MASQUERADE
COMMIT
# END OPENVPN RULES
' /etc/ufw/before.rules

# DEFAULT_FORWARD_POLICY="ACCEPT" in /etc/default/ufw

# ufw allow 1194/udp
# ufw allow OpenSSH
# ufw disable
# ufw enable
systemctl -f enable openvpn-server@server.service
systemctl start openvpn-server@server.service

su $myUser
mkdir -p ~/client-configs/files
cp $myPath/utilities/base.conf ~/client-configs/base.conf

cp $myPath/utilities/make_config.sh ~/client-configs/make_config.sh
chmod 700 ~/client-configs/make_config.sh

cd ~/client-configs
./make_config.sh client1
