#!/bin/sh
if [ `whoami` != root ]; then 
  echo "Please run as root."
  exit 1
fi

MY_SERVER_NAME=""

PGSQL_PASS=""

DRUPAL_DB_USER=""
DRUPAL_DB_USER_PASS=""
DRUPAL_DB=""

HELP=false

while getopts u:p:d:s:P:h option
do
  case "${option}"
  in    
  u) DRUPAL_DB_USER=$OPTARG;;
  p) DRUPAL_DB_USER_PASS=$OPTARG;;
  d) DRUPAL_DB=$OPTARG;;
  s) MY_SERVER_NAME=$OPTARG;;
  P) SQL_PASS=$OPTARG;;
  h) HELP=true;;
  esac
  OPT=true  
done

header() {
  HEADER=$1
  STRLENGTH=$(echo -n $HEADER | wc -m)
  DISPLAY="  " #65
  center=`expr $STRLENGTH / 2`
  max=`expr 33 - $center`
  echo $max
  for i in $(seq 1 $max)
  do
    DISPLAY+="-"    
  done
  DISPLAY+=" "$HEADER" "
  
  STRLENGTH=$(echo -n $DISPLAY | wc -m)
  max=`expr 65 - $STRLENGTH`
  for i in $(seq 1 $max)
  do
    DISPLAY+="-"
  done
    
  clear
  echo "  =================================================================="
  echo "$DISPLAY"
  echo "  =================================================================="
  echo ""
}

help() {
  header "Help"
  echo "If you pass this script no options or you forget to pass all the option, this script will ask you some questions."
  echo ""
  echo "-u tell the script what to name your drupal database user."
  echo "-p tell the script what password would you like to give your drupal database user"
  echo "-d tell the script what to name your drupal database."
  echo "-s tell the script what domanin or ip address you wish to use for drupal. In the file drupal.conf"
  echo "-P tell the script what password to give your MySQL root sql."
  echo "-h this Help Text."
  echo ""
  echo "IE: ./drupal_setup.sh -u drupal_db_user -p drupalPass -d drupal_db -s myWebsite.com -P sqlPass"
}

pkg_install() {
  pkg update

  pkg install -y apache24
  pkg install -y php72
  pkg install -y php72-zlib
  #pkg install -y php56-pecl-uploadprogress
  pkg install -y php72-extensions
  pkg install -y php72-curl
  pkg install -y mod_php72
  pkg install -y mysql56-server mysql56-client
  pkg install -y drupal7
  pkg install -y drush-php72  
}

mysql_secure() {
  delete_after=true
  
  pkg info expect
  
  if [ $? = 0 ]; then
    delete_after=false
  else
    pkg install -y expect
    delete_after=true
  fi
  
  SECURE_MYSQL=$(expect -c "
    set timeout 10
    spawn mysql_secure_installation
    expect \"Enter current password for root (enter for none):\"
    send \"\r\"
    expect \"Set root password?\"
    send \"y\r\"
    expect \"New password:\"
    send \"$SQL_PASS\r\"
    expect \"Re-enter new password:\"
    send \"$SQL_PASS\r\"
    expect \"Remove anonymous users?\"
    send \"y\r\"
    expect \"Disallow root login remotely?\"
    send \"y\r\"
    expect \"Remove test database and access to it?\"
    send \"y\r\"
    expect \"Reload privilege tables now?\"
    send \"y\r\"
    expect eof
    ")
    
  echo "$SECURE_MYSQL"
    
  if [ $delete_after = true ]; then
    pkg remove -y expect
  fi
  
  sed -i.bak '/innodb_large_prefix=true/d' /usr/local/my.cnf
  sed -i.bak '/innodb_file_format=barracuda/d' /usr/local/my.cnf
  sed -i.bak '/innodb_file_per_table=true/d' /usr/local/my.cnf
  
  echo 'innodb_large_prefix=true' >> /usr/local/my.cnf
  echo 'innodb_file_format=barracuda' >> /usr/local/my.cnf
  echo 'innodb_file_per_table=true' >> /usr/local/my.cnf  
}

mysql_setup() {
  
  
  sysrc mysql_enable=yes
  service mysql-server start
  
  mysql_secure
  
  mysql -uroot -p$SQL_PASS <<EOF
create database ${DRUPAL_DB};
create user ${DRUPAL_DB_USER}@localhost identified by '${DRUPAL_DB_USER_PASS}';
grant all privileges on ${DRUPAL_DB}.* to ${DRUPAL_DB_USER}@localhost identified by '${DRUPAL_DB_USER_PASS}';
flush privileges;
\q
EOF
    
  sed -i.bak '/mysql_enable/d' /etc/rc.conf
  
  echo 'mysql_enable="YES"' >> /etc/rc.conf
  
  service mysql-server restart  
}

drupal_conf() {
  cd /usr/local/www/drupal7/sites/default/
  cp default.settings.php settings.php 
  chown www:www settings.php
  
  mkdir /usr/local/www/drupal7/sites/default/files/private
  
  cd /usr/local/www/ 
  chown -R www:www drupal7/
  
  sed -i.bak '/$databases = array();/d' /usr/local/www/drupal7/sites/default/settings.php
  
  echo "\$databases['default']['default'] = array(
  'driver' => 'mysql',
  'database' => 'drupal_db',
  'username' => 'drupal_user',
  'password' => 'drupal_passwd',
  'host' => 'localhost',
  'charset' => 'utf8mb4',
  'collation' => 'utf8mb4_general_ci',
);" >> /usr/local/www/drupal7/sites/default/settings.php

  sed -i.bak "s/drupal_db/${DRUPAL_DB}/g" /usr/local/www/drupal7/sites/default/settings.php
  sed -i.bak "s/drupal_user/${DRUPAL_DB_USER}/g" /usr/local/www/drupal7/sites/default/settings.php
  sed -i.bak "s/drupal_passwd/${DRUPAL_DB_USER_PASS}/g" /usr/local/www/drupal7/sites/default/settings.php

  cat > /usr/local/etc/apache24/Includes/drupal.conf <<EOF
<VirtualHost *:80>
  ServerName server_name
  
  DocumentRoot /usr/local/www/drupal7
  <Directory "/usr/local/www/drupal7">
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
  </Directory>
</VirtualHost>
EOF

  sed -i.bak "s/server_name/${MY_SERVER_NAME}/g" /usr/local/etc/apache24/Includes/drupal.conf
}

apache_conf() {
  sed -i.bak '/^#LoadModule rewrite_module libexec\/apache24\/mod_rewrite.so/s/^#//g' /usr/local/etc/apache24/httpd.conf
    
  sed -i.bak '/AddType application\/x-httpd-php .php/d' /usr/local/etc/apache24/httpd.conf
  sed -i.bak '/\<IfModule mime_module\>/a\
    AddType application/x-httpd-php .php' /usr/local/etc/apache24/httpd.conf

  cat >> /usr/local/etc/apache24/httpd.conf <<EOF
<IfModule mime_module>
  AddType application/x-httpd-php .php
</IfModule>
EOF

  service apache24 start

  sed -i.bak '/apache24_enable/d' /etc/rc.conf
  
  echo 'apache24_enable="YES"' >> /etc/rc.conf
}

restart_apps() {
  service apache24 restart
  service mysql-server restart
}

please() {
  clear
  echo "  =================================================================="
  echo "Please go to $MY_SERVER_NAME/install.php not $MY_SERVER_NAME"
  echo "  =================================================================="
  echo ""
}

question() {
  HEADER=$1
  QUESTION=$2
  OPTION=$3
  RTN=""
  
  header "$HEADER"
  echo "    $QUESTION?"
  
  read KEY_INPUT
    
  case "${OPTION}"
  in    
  0) DRUPAL_DB_USER=$KEY_INPUT;;
  1) DRUPAL_DB_USER_PASS=$KEY_INPUT;;
  2) DRUPAL_DB=$KEY_INPUT;;
  3) MY_SERVER_NAME=$KEY_INPUT;;
  4) SQL_PASS=$KEY_INPUT;;
  esac
}

ask_questions() {
  question "Drupal Database user." "What would you like to name your drupal database user" 0
  
  question "Drupal Database user password." "What password would you like to give your database user" 1
  
  question "Database Name." "What would you like to name your database" 2
  
  question "Server Name." "What domain name or ip address would you like to use for your server" 3
  
  question "MySQL user password." "What password would you like to give your MySQL root user" 4
}

#------------------------------------------
#-    Main
#------------------------------------------
if [ $HELP = true ]; then
  help
  exit 1
fi

#If no options have been passed or if not all the options were passed, we ask the user.
if [ $OPT = false ] || [ -z $MY_SERVER_NAME ] || [ -z $SQL_PASS ] || [ -z $DRUPAL_DB_USER ] || [ -z $DRUPAL_DB_USER_PASS ] || [ -z $DRUPAL_DB ]; then
  ask_questions
fi

pkg_install

mysql_setup

drupal_conf

apache_conf

restart_apps

please