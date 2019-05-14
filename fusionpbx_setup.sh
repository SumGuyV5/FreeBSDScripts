#!/bin/sh
if [ `whoami` != root ]; then 
  echo "Please run as root."
  exit 1
fi
MY_SERVER_NAME="192.168.6.100"

pkg install --yes fusionpbx

sysrc memcached_enable="YES"
sysrc freeswitch_enable="YES"
sysrc freeswitch_flags="-nc -nonat"
sysrc freeswitch_user="freeswitch"
sysrc freeswitch_group="freeswitch"

service freeswitch restart

pkg install --yes apache24 mod_php72 

service freeswitch stop

#copy the default conf directory
mkdir -p /usr/local/etc/freeswitch
cp -R /usr/local/www/fusionpbx/resources/templates/conf/* /usr/local/etc/freeswitch

#copy the scripts
cp -R /usr/local/www/fusionpbx/resources/install/scripts /usr/local/share/freeswitch

#default ownership
chown -R www:www /usr/local/etc/freeswitch
chown -R www:www /var/lib/freeswitch
chown -R www:www /usr/local/share/freeswitch
chown -R www:www /var/log/freeswitch
chown -R www:www /var/run/freeswitch

#enable the services
sysrc freeswitch_user="www"
sysrc freeswitch_group="www"
service freeswitch restart

#start the service
service memcached start

sed -i.bak '/^#LoadModule rewrite_module libexec\/apache24\/mod_rewrite.so/s/^#//g' /usr/local/etc/apache24/httpd.conf
  
sed -i.bak '/^#LoadModule mime_magic_module libexec\/apache24\/mod_mime_magic.so/s/^#//g' /usr/local/etc/apache24/httpd.conf
    
sed -i.bak '/AddType application\/x-httpd-php .php/d' /usr/local/etc/apache24/httpd.conf
sed -i.bak '/\<IfModule mime_module\>/a\
    AddType application/x-httpd-php .php' /usr/local/etc/apache24/httpd.conf

cat > /usr/local/etc/apache24/Includes/fusionpbx.conf <<EOF
<VirtualHost *:80>
  ServerName $MY_SERVER_NAME
  
  DocumentRoot /usr/local/www/fusionpbx
  <Directory "/usr/local/www/fusionpbx">
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
  </Directory>
</VirtualHost>
EOF

sysrc apache24_enable="YES"
service apache24 restart