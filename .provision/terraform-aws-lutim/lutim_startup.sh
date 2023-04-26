#!/bin/bash

echo "**********************************************************************"
echo "                                                                     *"
echo "Install dependencies                                                 *"
echo "                                                                     *"
echo "**********************************************************************"

SUDO=sudo
$SUDO apt update
$SUDO apt install jq -y
$SUDO apt install wget -y
$SUDO apt install unzip
$SUDO apt install carton -y
$SUDO apt install build-essential -y
$SUDO apt install nginx -y
$SUDO apt install libssl-dev -y
$SUDO apt install libio-socket-ssl-perl -y
$SUDO apt install liblwp-protocol-https-perl -y
$SUDO apt install zlib1g-dev -y
$SUDO apt install libmojo-sqlite-perl -y
$SUDO apt install libpq-dev -y

echo "**********************************************************************"
echo "                                                                     *"
echo "Configuring the Application                                          *"
echo "                                                                     *"
echo "**********************************************************************"

sleep 10;
version=$(curl -s https://framagit.org/api/v4/projects/1/releases | jq '.[]' | jq -r '.name' | head -1)
echo $version
pushd ${directory} 
$SUDO wget https://framagit.org/fiat-tux/hat-softwares/lutim/-/archive/$version/lutim-$version.zip
$SUDO unzip lutim-$version.zip
$SUDO chown ${user} lutim-$version
$SUDO chgrp ${group} lutim-$version
pushd lutim-$version

echo "**********************************************************************"
echo "                                                                     *"
echo "Install Carton Packages                                              *"
echo "                                                                     *"
echo "**********************************************************************"

$SUDO carton install --deployment --without=test --without=sqlite --without=mysql

sleep 10;

$SUDO cp lutim.conf.template lutim.conf

sed -i 's/127.0.0.1/0.0.0.0/'  lutim.conf
sed -i 's/#contact/contact/g' lutim.conf
sed -i "s/John Doe/${contact_user}/g" lutim.conf
sed -i "s/admin[at]example.com/${contact_lutim}/g" lutim.conf
sed -i "s/fdjsofjoihrei/${secret_lutim}/g" lutim.conf
sed -i '153 , 158 s/#/ /g' lutim.conf

echo "**********************************************************************"
echo "                                                                     *"
echo "Run the Application                                                  *"
echo "                                                                     *"
echo "**********************************************************************"

$SUDO carton exec hypnotoad script/lutim

