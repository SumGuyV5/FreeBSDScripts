#!/bin/sh
if [ `whoami` != root ]; then 
  echo "Please run as root."
  exit 1
fi

service apache24 stop
service mysql-server stop

pkg remove -y apache24
pkg remove -y php72
pkg remove -y php72-zlib
pkg remove -y php72-extensions
pkg remove -y php72-curl
pkg remove -y mod_php72
pkg remove -y mysql56-server 
pkg remove -y mysql56-client
pkg remove -y drupal7
pkg remove -y drupal8
pkg remove -y drush-php72 

pkg remove -y php72-mysqli
pkg remove -y php72-hash
pkg remove -y php72-gd
pkg remove -y php72-pdo_mysql

rm /usr/local/my.cnf

rm -R /usr/local/www/drupal7

rm -R /usr/local/www/drupal8

rm -R /usr/local/etc/apache24

rm -R /var/db/mysql