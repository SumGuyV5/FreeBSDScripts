#!/usr/local/bin/bash
if [ `whoami` != root ]; then 
  echo "Please run as root."
  exit 1
fi

MY_USER=""
MY_ENV=""
MY_PROJECT=""
MY_SERVER_NAME=""

USER_HOME=$(eval echo "~$MY_USER")

HELP=false
OPT=false

while getopts u:e:p:s:h option
do
  case "${option}"
  in    
  u) MY_USER=$OPTARG;;
  e) MY_ENV=$OPTARG;;
  p) MY_PROJECT=$OPTARG;;
  s) MY_SERVER_NAME=$OPTARG;;
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
  echo "-u tell the script what FreeBSD user would you like to use."
  echo "-e tell the script what to name your virtual environment."
  echo "-p tell the script what to name your project."
  echo "-s tell the script what domain name or ip address to use for django. settings.py ALLOWED_HOSTS and mydjango.conf"
  echo "-h this Help Text."
  echo ""
  echo "IE: ./django_setup.sh -u freebsdUser -e myenv -p myproject -s myWebsite.com"
}

write_gunicorn_start() {
  cd $1
  cat > bin/gunicorn_start <<EOF
#!/bin/bash

NAME="myproject"                                      # Django Project Name
DJANGODIR=myhome/myenv/myproject                      # Django Project Directory
SOCKFILE=myhome/myenv/myproject/run/gunicorn.sock     # Gunicorn Sock File
USER=myuser                                           # Django Project Running under user vagrant
GROUP=myuser                                          # Django Project Running under group vagrant
NUM_WORKERS=3
DJANGO_SETTINGS_MODULE=myproject.settings             # change 'myproject' with your project name
DJANGO_WSGI_MODULE=myproject.wsgi                     # change 'myproject' with your project name
  
echo "Starting \$NAME as `whoami`"
  
# Activate the virtual environment
cd \$DJANGODIR
source ../bin/activate
export DJANGO_SETTINGS_MODULE=\$DJANGO_SETTINGS_MODULE
export PYTHONPATH=\$DJANGODIR:\$PYTHONPATH
  
# Create the run directory if it doesn't exist
RUNDIR=\$(dirname \$SOCKFILE)
test -d \$RUNDIR || mkdir -p \$RUNDIR
  
# Start your Django Unicorn
# Programs meant to be run under supervisor should not daemonize themselves (do not use --daemon)
exec ../bin/gunicorn \${DJANGO_WSGI_MODULE}:application \
--name \$NAME \
--workers \$NUM_WORKERS \
--user=\$USER --group=\$GROUP \
--bind=unix:\$SOCKFILE \
--log-level=debug \
--log-file=-
EOF
  sed -i.bak "s#myhome#${USER_HOME}#g" bin/gunicorn_start
  sed -i.bak "s/myuser/${MY_USER}/g" bin/gunicorn_start
  sed -i.bak "s/myenv/${MY_ENV}/g" bin/gunicorn_start
  sed -i.bak "s/myproject/${MY_PROJECT}/g" bin/gunicorn_start  
}

write_supervisord() {
  cat >> supervisord.conf <<EOF
  
[program:myproject]
command = sh myhome/myenv/bin/gunicorn_start
user = myuser
stdout_logfile = myhome/myenv/logs/gunicorn_supervisor.log
redirect_stderr = true
environment=LANG=en_US.UTF-8,LC_ALL=en_US.UTF-8
EOF
  sed -i.bak "s#myhome#${USER_HOME}#g" supervisord.conf
  sed -i.bak "s/myuser/${MY_USER}/g" supervisord.conf
  sed -i.bak "s/myenv/${MY_ENV}/g" supervisord.conf
  sed -i.bak "s/myproject/${MY_PROJECT}/g" supervisord.conf
}

write_mydjango() {
  cat > mydjango.conf <<EOF
upstream myproject_server {
  server unix:/myhome/myenv/myproject/run/gunicorn.sock fail_timeout=0;
}
  
server {
  listen   80;
  server_name www.djangofreebsd.com;
    
  client_max_body_size 4G;
    
  access_log myhome/myenv/logs/nginx-access.log;
  error_log myhome/myenv/logs/nginx-error.log;
    
  location /static/ {
    alias   myhome/myenv/myproject/static/;
  }
    
  location /media/ {
    alias   myhome/myenv/myproject/media/;
  }
    
  location / {
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header Host \$http_host;
    proxy_redirect off;
      
    # Try to serve static files from nginx, no point in making an
    # *application* server like Unicorn/Rainbows! serve static files.
    if (!-f \$request_filename) {
      proxy_pass http://myproject_server;
      break;
    }
  }
    
  # Error pages
  error_page 500 502 503 504 /500.html;
  location = /500.html {
    root myhome/myenv/myproject/static/;
  }
}  
EOF
  sed -i.bak "s#myhome#${USER_HOME}#g" mydjango.conf
  sed -i.bak "s/www.djangofreebsd.com/${MY_SERVER_NAME}/g" mydjango.conf
  sed -i.bak "s/myuser/${MY_USER}/g" mydjango.conf
  sed -i.bak "s/myenv/${MY_ENV}/g" mydjango.conf
  sed -i.bak "s/myproject/${MY_PROJECT}/g" mydjango.conf
}

write_nginx() {
  sed -i.bak "/include vhost\/\*.conf;/d" nginx.conf
  sed -i.bak '121i\
  include vhost/*.conf;' nginx.conf  
}

step1() {
  pkg update
  pkg install -y python3
  pkg install -y py36-pip
  
  ln -s /usr/local/bin/python3 /usr/local/bin/python
  ln -s /usr/local/bin/pip-3.6 /usr/local/bin/pip
  
  pip install --upgrade pip
  
  pkg install -y sqlite3
  pkg install -y py36-sqlite3
  
  pip install virtualenv
}

step2() {
  # Login as user
  DIR="${USER_HOME}/${MY_ENV}"
  rm -R $DIR
  
  COMMAND="virtualenv --python=python3.6 ${MY_ENV}; " 
    
  COMMAND+="cd ${MY_ENV}; "  
  COMMAND+="source bin/activate; "
  COMMAND+="pip install django; "
  COMMAND+="pip install gunicorn; "
  
  COMMAND+="django-admin startproject ${MY_PROJECT}; "
  
  COMMAND+="cd ${MY_PROJECT}; "
  
  su $MY_USER -c "${COMMAND}"
  
  DIR="${USER_HOME}/${MY_ENV}/${MY_PROJECT}/${MY_PROJECT}"
  
  STATIC_ROOT="STATIC_ROOT='${USER_HOME}/${MY_ENV}/${MY_PROJECT}/static/'"
  STATIC_URL="STATIC_URL='/static/'"
  
  MEDIA_ROOT="MEDIA_ROOT='${USER_HOME}/${MY_ENV}/${MY_PROJECT}/media/'"
  MEDIA_URL="MEIDA_URL='/media/'"
  
  echo $STATIC_ROOT >> $DIR/settings.py
  echo $STATIC_URL >> $DIR/settings.py
  
  echo $MEDIA_ROOT >> $DIR/settings.py
  echo $MEDIA_URL >> $DIR/settings.py
  
  sed -i.bak "s/ALLOWED_HOSTS = \[/ALLOWED_HOSTS = \['${MY_SERVER_NAME}',/g" $DIR/settings.py
  
  COMMAND="cd ${MY_ENV}; "
  COMMAND+="cd ${MY_PROJECT}; "
  COMMAND+="source bin/activate; "
  COMMAND+="python manage.py collectstatic; "
  
  su $MY_USER -c $COMMAND
  
  write_gunicorn_start "${USER_HOME}/${MY_ENV}"
  
  COMMAND="cd ${MY_ENV}; "
  COMMAND+="cd ${MY_PROJECT}; "
  COMMAND+="source bin/activate; "
  COMMAND+="chmod u+x bin/gunicorn_start; "
  
  su $MY_USER -c $COMMAND
}

step3() {
  pkg install -y py27-supervisor
  
  sysrc supervisord_enable=yes
  service supervisord start
  
  cd /usr/local/etc/
  write_supervisord
 
  mkdir -p ${USER_HOME}/${MY_ENV}/logs/
  touch ${USER_HOME}/${MY_ENV}/logs/gunicorn_supervisor.log
  
  service supervisord restart
  supervisorctl status
}

step4() {
  pkg install -y nginx
  
  cd /usr/local/etc/nginx/
  mkdir -p vhost/
  
  cd vhost/
  
  write_mydjango
  
  cd /usr/local/etc/nginx/
  
  write_nginx
  
  nginx -t
  sysrc nginx_enable=yes
  
  service supervisord restart
  service nginx start  
}

restartall() {
  service supervisord restart
  service nginx restart
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
  0) MY_USER=$KEY_INPUT;;
  1) MY_ENV=$KEY_INPUT;;
  2) MY_PROJECT=$KEY_INPUT;;
  3) MY_SERVER_NAME=$KEY_INPUT;;
  esac
}

ask_questions() {
  question "FreeBSD user to use." "What FreeBSD user would you like to use" 0
  
  question "Virtual Environment." "What would you like to name your virtual environment" 1
  
  question "Project Name." "What would you like to name your project" 2
  
  question "Server Name." "What domain name or ip address would you like to use for your server" 3
}

#------------------------------------------
#-    Main
#------------------------------------------

if [ $HELP = true ]; then
  help
  exit 1
fi

#If no options have been passed or if not all the options were passed, we ask the user.
if [ $OPT = false ] || [ -z $MY_USER ] || [ -z $MY_ENV ] || [ -z $MY_PROJECT ] || [ -z $MY_SERVER_NAME ]; then
  ask_questions
fi


USER_HOME=$(eval echo "~$MY_USER")

step1
step2
step3
step4
restartall