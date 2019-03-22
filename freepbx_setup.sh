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

PHP_VER=php70

MY_SERVER_NAME="localhost"

install_pkg() {
  pkg install -y asterisk13
  pkg install -y apache24 mysql56-server mysql56-client mongodb36 bison flex node
  pkg install -y mod_$PHP_VER $PHP_VER $PHP_VER-curl $PHP_VER-mysqli $PHP_VER-pear $PHP_VER-gd $PHP_VER-pdo_mysql $PHP_VER-gettext $PHP_VER-openssl $PHP_VAR-mbstring
  pkg install -y $PHP_VER-extensions 
  pkg install -y curl sox ncurses openssl mpg123 libxml2 newt sqlite3 unixODBC mysql-connector-odbc-unixodbc-mysql56 gnupg
}

remove_pkg() {
  pkg remove -y asterisk13
  pkg remove -y apache24 mysql56-server mysql56-client mongodb36 bison flex node
  pkg remove -y mod_$PHP_VER $PHP_VER $PHP_VER-curl $PHP_VER-mysqli $PHP_VER-pear $PHP_VER-gd $PHP_VER-pdo_mysql $PHP_VER-gettext $PHP_VER-openssl $PHP_VAR-mbstring
  pkg remove -y $PHP_VER-extensions 
  pkg remove -y curl sox ncurses openssl mpg123 libxml2 newt sqlite3 unixODBC mysql-connector-odbc-unixodbc-mysql56 gnupg
}

rc_sys() {
  sysrc apache24_enable="YES"
  sysrc asterisk_enable="YES"
  sysrc asterisk_user=$ASTERISK_USER
  sysrc asterisk_group=$ASTERISK_USER
  sysrc mysql_enable="YES"
}

mysql_setup() {
  cat > /usr/local/etc/odbc.ini <<EOF
[MySQL-asteriskcdrdb]
Description=MySQL connection to 'asteriskcdrdb' database
driver=MySQL
server=localhost
database=asteriskcdrdb
Port=3306
option=3
EOF

  cat > /usr/local/etc/odbcinst.ini <<EOF
[MySQL]
Description=ODBC for MySQL
Driver=/usr/local/lib/libmyodbc5a.so
UsageCount=20002
EOF
}

apache_setup() {
  cp /usr/local/etc/php.ini-production /usr/local/etc/php.ini
  sed -i.bak 's/\(^upload_max_filesize = \).*/\120M/' /usr/local/etc/php.ini
  sed -i.bak 's/\(^memory_limit = \).*/\1256M/' /usr/local/etc/php.ini

  cp /usr/local/etc/apache24/httpd.conf /usr/local/etc/apache24/httpd.conf_orig
  sed -i.bak -E "s/^(User|Group).*/\1 ${ASTERISK_USER}/" /usr/local/etc/apache24/httpd.conf
  #sed -i.bak 's/AllowOverride None/AllowOverride All/' /usr/local/etc/apache24/httpd.conf
  
  sed -i.bak '/^#LoadModule rewrite_module libexec\/apache24\/mod_rewrite.so/s/^#//g' /usr/local/etc/apache24/httpd.conf
  sed -i.bak '/^#LoadModule mime_magic_module libexec\/apache24\/mod_mime_magic.so/s/^#//g' /usr/local/etc/apache24/httpd.conf
  
  sed -i.bak '/\<IfModule mime_module\>/a\
    AddType application/x-httpd-php .php
    ' /usr/local/etc/apache24/httpd.conf
    
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
EOF
}

start_service() {
  safe_asterisk -U asterisk -G asterisk
  #service asterisk restart
  service mysql-server restart
  service apache24 restart
}

stop_service() {
  service asterisk stop
  service mysql-server stop
  service apache24 stop
}

freepbx_installer_freebsd_fix()
{
  #there is no runuser in freebsd so repalce it with sudo
  sed -i.bak 's/runuser . \. \$answers\[.user.\] \. . -s \/bin\/bash -c .cd ~\/ &&/sudo/g' /usr/src/freepbx/installlib/installcommand.class.php
  
  #the top sed command leaves some single quotes behind this removes them
  #line 268
  sed -i.bak "s/\\\'core show version\\\'/'core show version'/g" /usr/src/freepbx/installlib/installcommand.class.php
  sed -i.bak "s/', \$tmpout, \$ret/, \$tmpout, \$ret/g" /usr/src/freepbx/installlib/installcommand.class.php
    
  #the top sed command leaves some single quotes behind this removes them
  #line 761
  sed -i.bak "s/\\\'module reload manager\\\'/'module reload manager'/g" /usr/src/freepbx/installlib/installcommand.class.php
  sed -i.bak "s/',\$o,\$r/,\$o,\$r/g" /usr/src/freepbx/installlib/installcommand.class.php

  
  #if we don't give this field a length of 191 we get the following error
  #An exception occurred while executing 'CREATE TABLE freepbx_log (id INT AUTO_INCREMENT NOT NULL, time DATETIME NOT NULL, section VARCHAR(50) DEFAULT NULL, level VARCHAR(255) DEFAULT 
  #'error' NOT NULL, status INT DEFAULT 0 NOT NULL, message LONGTEXT NOT NULL, INDEX time (time, level), PRIMARY KEY(id)) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci 
  #ENGINE = InnoDB':
  
  #SQLSTATE[42000]: Syntax error or access violation: 1071 Specified key was too long; max key length is 767 bytes
  
  #mysql56 on BSD has a issues with VARCHAR(255) when in utf8mb4 mode?
  #is there a better solution then this?
  sed -i.bak 's/<field name="level" type="string" default="error"\/>/<field name="level" type="string" length="191" default="error"\/>/g' /usr/src/freepbx/module.xml  
}

freepbx_setup() {
  cd /usr/src

  #fetch http://mirror.freepbx.org/modules/packages/freepbx/freepbx-14.0-latest.tgz
  tar vxfz freepbx-14.0-latest.tgz
  
  freepbx_installer_freebsd_fix
  
  cd freepbx
  touch /usr/local/etc/asterisk/{modules,ari,statsd}.conf
}


#------------------------------------------
#-    Main
#------------------------------------------
#stop_service

#remove_pkg
install_pkg

rc_sys

mysql_setup

apache_setup

start_service

#freepbx_installer_freebsd_fix

freepbx_setup
