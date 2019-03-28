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

remove_pkg() {
  pkg remove -y asterisk13
  pkg remove -y apache24 mysql56-server mysql56-client mongodb36 bison flex node
  pkg remove -y mod_$PHP_VER $PHP_VER $PHP_VER-curl $PHP_VER-mysqli $PHP_VER-pear $PHP_VER-gd $PHP_VER-pdo_mysql $PHP_VER-gettext $PHP_VER-openssl $PHP_VAR-mbstring
  pkg remove -y $PHP_VER-extensions 
  pkg remove -y curl sox ncurses openssl mpg123 libxml2 newt sqlite3 unixODBC mysql-connector-odbc-unixodbc-mysql56 gnupg
  
  pkg remove -y npm
}


stop_service() {
  service asterisk stop
  service mysql-server stop
  service apache24 stop
}

remove_files() {
  pw user del asterisk
  pw group del asterisk
  
  rm -r /etc/freepbx.conf
  rm -r /etc/amportal.conf
  
  rm -r /usr/src/freepbx
  rm -r /usr/local/www/freepbx
  rm -r /usr/etc/asterisk
  rm -r /usr/local/freepbx
  rm -r /etc/freepbx.conf
  rm -r /usr/home/asterisk
  rm -r /home/asterisk
  rm -r /usr/local/share/asterisk
  rm -r /usr/local/etc/asterisk
  rm -r /var/db/asterisk
  rm -r /var/db/mysql/asterisk
  rm -r /var/log/asterisk
  rm -r /var/spool/asterisk
  rm -r /var/run/asterisk
  rm -r /var/run/sudo/ts/asterisk 
  
  rm -r  /usr/local/share/apache24
  rm -r /usr/local/share/doc/apache24
  rm -r /usr/local/www/apache24
  rm -r /usr/local/include/apache24
  rm -r /usr/local/etc/apache24
  rm -r /usr/local/etc/rc.d/apache24
  rm -r /usr/local/libexec/apache24
  
  rm -r /var/db/mysql
  rm -r /var/db/mysql/mysql
  
  rm -r /usr/local/etc/odbc.ini
  rm -r /etc/odbc.ini
  
  rm -r /usr/local/etc/odbcinst.ini
  
  rm -r /var/db/mysql/my.cnf
  
  sed -i.bak '/apache24_enable="YES"/d' /etc/rc.conf
  sed -i.bak '/asterisk_enable="YES"/d' /etc/rc.conf
  sed -i.bak '/asterisk_user="asterisk"/d' /etc/rc.conf
  sed -i.bak '/asterisk_group="asterisk"/d' /etc/rc.conf
  sed -i.bak '/mysql_enable="YES"/d' /etc/rc.conf
  sed -i.bak '/mysql_args="--character-set-server=utf8"/d' /etc/rc.conf
}


#------------------------------------------
#-    Main
#------------------------------------------
echo "This script is a work in progress"
stop_service

remove_pkg

remove_files



#sudo pkg install pam_fprint pam_google_authenticator pam_helper pam_jail pam_kde pam_krb5 pam_krb5-rh pam_ldap pam_mkhomedir pam_mount pam_mysql pam_ocra pam_p11 pam_per_user pam_pseudo pam_pwdfile pam_require pam_search_list pam_ssh_agent_auth pam_wrapper pam_yubico
