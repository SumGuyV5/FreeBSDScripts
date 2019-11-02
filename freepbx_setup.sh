#!/bin/sh
if [ `whoami` != root ]; then 
  echo "Please run as root."
  exit 1
fi
if [ "$1" = "-h" ]; then 
  echo "Please run as root."
  exit 1
fi

#this is a work in progress

ASTERISK_USER="asterisk"

PHP_VER=php71

MY_SERVER_NAME="localhost"

FREEPBX_VER="freepbx-14.0-latest.tgz"

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

install_pkg() {
  pkg install -y bash sudo
  pkg install -y asterisk13  
  pkg install -y apache24 mysql57-server mysql57-client mongodb36 bison flex node
  pkg install -y mod_$PHP_VER $PHP_VER $PHP_VER-curl $PHP_VER-mysqli $PHP_VER-pear $PHP_VER-gd $PHP_VER-pdo_mysql $PHP_VER-gettext $PHP_VER-openssl $PHP_VER-mbstring
  pkg install -y $PHP_VER-sysvsem
  pkg install -y $PHP_VER-extensions 
  pkg install -y curl sox ncurses openssl mpg123 libxml2 newt sqlite3 unixODBC mysql-connector-odbc-unixodbc-mysql57 gnupg
  
  pkg install -y npm
  pkg install -y linux_base-c7
}

rc_sys() {
  sysrc apache24_enable="YES"
  sysrc asterisk_enable="YES"
  sysrc asterisk_user=$ASTERISK_USER
  sysrc asterisk_group=$ASTERISK_USER
  sysrc mysql_enable="YES"
  sysrc mysql_args="--character-set-server=utf8"
}

mysql_setup() {
#  cat > /var/db/mysql/my.cnf <<EOF
#[mysqld]
#init_connect='SET collation_connection = utf8_general_ci'
#init_connect='SET NAMES utf8'
#default-character-set=utf8
#character-set-server=utf8
#collation-server=utf8_general_ci
#skip-character-set-client-handshake
#sql_mode=NO_ENGINE_SUBSTITUTION,STRICT_TRANS_TABLES
#EOF

#chown mysql:mysql /var/db/mysql/my.cnf

  cat > /usr/local/etc/odbc.ini <<EOF
[MySQL-asteriskcdrdb]
Description=MySQL connection to 'asteriskcdrdb' database
driver=MySQL
server=localhost
database=asteriskcdrdb
Port=3306
option=3
Charset=utf8
EOF

  cat > /usr/local/etc/odbcinst.ini <<EOF
[MySQL]
Description=ODBC for MySQL
Driver=/usr/local/lib/libmyodbc5w.so
UsageCount=20003
EOF
}

apache_setup() {
  cp /usr/local/etc/php.ini-production /usr/local/etc/php.ini
  sed -i.bak 's/\(^upload_max_filesize = \).*/\120M/' /usr/local/etc/php.ini
  sed -i.bak 's/\(^memory_limit = \).*/\1256M/' /usr/local/etc/php.ini

  cp /usr/local/etc/apache24/httpd.conf /usr/local/etc/apache24/httpd.conf_orig
  sed -i.bak -E "s/^(User|Group).*/\1 ${ASTERISK_USER}/" /usr/local/etc/apache24/httpd.conf
  sed -i.bak 's/AllowOverride None/AllowOverride All/' /usr/local/etc/apache24/httpd.conf
  
  sed -i.bak '/^#LoadModule rewrite_module libexec\/apache24\/mod_rewrite.so/s/^#//g' /usr/local/etc/apache24/httpd.conf
  sed -i.bak '/^#LoadModule mime_magic_module libexec\/apache24\/mod_mime_magic.so/s/^#//g' /usr/local/etc/apache24/httpd.conf
  
  sed -i.bak '/AddType application\/x-httpd-php .php/d' /usr/local/etc/apache24/httpd.conf
  
  sed -i.bak '/\<IfModule mime_module\>/a\
    AddType application/x-httpd-php .php
    ' /usr/local/etc/apache24/httpd.conf
    
  sed -i.bak '/DirectoryIndex index.html/d' /usr/local/etc/apache24/httpd.conf
  
  sed -i.bak '/\<IfModule dir_module\>/a\
    DirectoryIndex index.html index.php
    ' /usr/local/etc/apache24/httpd.conf
    
  # apache config ssl
  sed -i.bak '/^#LoadModule ssl_module libexec\/apache24\/mod_ssl.so/s/^#//g' /usr/local/etc/apache24/httpd.conf
  
  mkdir -p /usr/local/etc/apache24/ssl
  cd /usr/local/etc/apache24/ssl
  openssl genrsa -rand -genkey -out private.key 2048
  
  openssl req -new -x509 -days 365 -key private.key -out certificate.crt -sha256 -subj "/C=CA/ST=ONTARIO/L=TORONTO/O=Global Security/OU=IT Department/CN=${MY_SERVER_NAME}"
  
  cat > /usr/local/etc/apache24/modules.d/020_mod_ssl.conf <<EOF
Listen 443
SSLProtocol ALL -SSLv2 -SSLv3
SSLCipherSuite HIGH:MEDIUM:!aNULL:!MD5
SSLPassPhraseDialog builtin
SSLSessionCacheTimeout 300
EOF
        
  cat > /usr/local/etc/apache24/Includes/freepbx.conf <<EOF
<VirtualHost *:80>
  ServerName $MY_SERVER_NAME
  
  DocumentRoot /usr/local/www/freepbx/admin
  <Directory "/usr/local/www/freepbx/admin">
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
  </Directory>
</VirtualHost>

<VirtualHost *:443>
  ServerName $MY_SERVER_NAME
  
  SSLEngine on
  SSLCertificateFile "/usr/local/etc/apache24/ssl/certificate.crt"
  SSLCertificateKeyFile "/usr/local/etc/apache24/ssl/private.key"
  DocumentRoot /usr/local/www/freepbx/admin
  <Directory "/usr/local/www/freepbx/admin">
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
  </Directory>
</VirtualHost>
EOF
}

start_service() {
  service asterisk restart
  service mysql-server restart
  service apache24 restart
}

linux() {
  mkdir /home/asterisk
  chown asterisk:asterisk /home/asterisk
  pw usermod asterisk -d /home/asterisk/ -m
  chsh -s /usr/local/bin/bash asterisk
  
  #Reload failed because retrieve_conf encountered an error: 127
  #fixs this
  ln -s /usr/local/bin/php /usr/bin/php
  
  #Process Mangement Module will not upgrade from gui
  #Node is not installed
  #  Error(s) installing pm2:
  #    * Failed to run installation scripts
  ln -s /usr/local/bin/node /usr/bin/node
  ln -s /usr/local/bin/npm /usr/bin/npm
  
  ln -s /usr/local/bin/gpg /usr/bin/gpg
  
  ln -s /usr/local/bin/bash /bin/bash
  
  #simple script to take the runuser command that FreePBX uses and turn it in to su command.
  cat > /usr/local/bin/runuser <<EOF
#!/bin/sh
su \$1 \$4 "\$5"
EOF

chmod 655 /usr/local/bin/runuser
  
  cat > /etc/fstab <<EOF
#Some programs need linprocfs mounted on /compat/linux/proc.  Add the
#following line to /etc/fstab:

#linprocfs   /compat/linux/proc  linprocfs       rw      0       0

#Then run "mount /compat/linux/proc".

#Some programs need linsysfs mounted on /compat/linux/sys.  Add the
#following line to /etc/fstab:

#linsysfs    /compat/linux/sys   linsysfs        rw      0       0

#Then run "mount /compat/linux/sys".

#Some programs need tmpfs mounted on /compat/linux/dev/shm.  Add the
#following line to /etc/fstab:

tmpfs    /compat/linux/dev/shm  tmpfs   rw,mode=1777    0       0
#Then run "mount /compat/linux/dev/shm"
EOF

mount /compat/linux/dev/shm
}

freepbx_setup() {
  MYSQL_PASS=$(tail -1 /root/.mysql_secret)
  mysqladmin -u root -p$MYSQL_PASS password ''
  
  mkdir -p /usr/src
  cd /usr/src

  MIRROR="mirror"
  while [ ! -f "$FREEPBX_VER" ]
  do
    URL=http://$MIRROR.freepbx.org/modules/packages/freepbx/$FREEPBX_VER
    header $URL
    fetch http://$MIRROR.freepbx.org/modules/packages/freepbx/$FREEPBX_VER
    sleep 1
    case "$MIRROR" in
      mirror)
              MIRROR="mirror1"
               ;;
      mirror1)
              MIRROR="mirror2"
               ;;
      *)
              MIRROR="mirror"
               ;;
    esac      
  done
  rm -R freepbx
  tar vxfz $FREEPBX_VER
    
  cd freepbx
  touch /usr/local/etc/asterisk/{modules,ari,statsd}.conf
  ./install -n
}

post_install() {
  MYSQL_PASS=$(tail -1 /root/.mysql_secret)
  mysqladmin -u root password '$MYSQL_PASS'
  
  /usr/local/freepbx/bin/fwconsole set CERTKEYLOC /usr/local/etc/asterisk/keys
  /usr/local/freepbx/sbin/fwconsole reload
  
  header "FreePBX Modules to not install."
  echo "Call Flow Control - deprecated constructor"
  echo "Digium Phones Config - deprecated constructor"
  
  echo "Digium Addons - requers RPM binary"
  
  echo "iSymphonyV3 - deprecated constructor"
  
  echo "User Control Panel - command line only? sudo /usr/local/freepbx/sbin/fwconsole ma install ucp"
  echo "XMPP - command line only? sudo /usr/local/freepbx/sbin/fwconsole ma install xmpp"
}


#------------------------------------------
#-    Main
#------------------------------------------
header "This script is a work in progress"

install_pkg

linux

rc_sys

mysql_setup

apache_setup

start_service

freepbx_setup

post_install
