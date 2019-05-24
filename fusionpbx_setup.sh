#!/bin/sh
if [ `whoami` != root ]; then 
  echo "Please run as root."
  exit 1
fi
MY_SERVER_NAME="192.168.1.16"
DB_PASSWORD=password123
PORTS=false

header() {
  HEADER=$1
  STRLENGTH=$(echo -n $HEADER | wc -m)
  DISPLAY="  " #65
  center=`expr $STRLENGTH / 2`
  max=`expr 33 - $center`
  echo $max
  for i in $(seq 1 $max)
  do
    DISPLAY="${DISPLAY}-"    
  done
  DISPLAY="${DISPLAY} "$HEADER" "
  
  STRLENGTH=$(echo -n $DISPLAY | wc -m)
  max=`expr 65 - $STRLENGTH`
  for i in $(seq 1 $max)
  do
    DISPLAY="${DISPLAY}-"
  done
    
  clear
  echo "  =================================================================="
  echo "$DISPLAY"
  echo "  =================================================================="
  echo ""
}

question() {
  HEADER=$1
  QUESTION=$2
  RTN=0
  
  header "$HEADER"
  echo "    $QUESTION? [Y/N]"
  
  read yesno
  
  case $yesno in
    [Yy]* ) RTN=1;;
    [Nn]* ) RTN=0;;
  esac
  
  return $RTN
}

install_sw() {
  PACKAGE=$1
  DIR="$2/$PACKAGE"
  if [ "$PORTS" = true ]; then
    cd $DIR
    make deinstall
    make -DBATCH install clean
  else
    pkg install --yes $PACKAGE
  fi
}

question "use ports." "would you like to use ports over pkg"
if [ "$?" = 1 ]; then
  PORTS=true
fi

install_sw fusionpbx /usr/ports/www

sysrc memcached_enable="YES"
sysrc freeswitch_enable="YES"
sysrc freeswitch_flags="-nc -nonat"
sysrc freeswitch_user="freeswitch"
sysrc freeswitch_group="freeswitch"

service freeswitch restart

install_sw apache24 /usr/ports/www
install_sw mod_php72 /usr/ports/www

question "postgresql install." "would you like to install postgresql10-server"
if [ "$?" = 1 ]; then
  install_sw postgresql10-server /usr/ports/databases
  
  service postgresql start

  sysrc postgresql_enable="YES"
  
  /usr/local/etc/rc.d/postgresql initdb

  sudo -u postgres /usr/local/bin/pg_ctl -D /var/db/postgres/data10 -l logfile start

  service postgresql restart
  
  sudo -u postgres psql -c "DROP DATABASE fusionpbx;"
  sudo -u postgres psql -c "DROP DATABASE freeswitch;"
  sudo -u postgres psql -c "DROP ROLE fusionpbx;"
  sudo -u postgres psql -c "DROP ROLE freeswitch;"
  
  sudo -u postgres psql -c "CREATE DATABASE fusionpbx;"
  sudo -u postgres psql -c "CREATE DATABASE freeswitch;"
  sudo -u postgres psql -c "CREATE ROLE fusionpbx WITH SUPERUSER LOGIN PASSWORD '$DB_PASSWORD';"
  sudo -u postgres psql -c "CREATE ROLE freeswitch WITH SUPERUSER LOGIN PASSWORD '$DB_PASSWORD';"
  sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE fusionpbx to fusionpbx;"
  sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE freeswitch to fusionpbx;"
  sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE freeswitch to freeswitch;"  
fi

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