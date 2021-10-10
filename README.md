# FreeBSDScripts
FreeBSD Scripts to make my life easy.

## bash_setup.sh

Sets user up with bash.

```sh
./bash_setup.sh Richard
```

Will make bash the default shell for user 'Richard'. The script will ask you if you wish to install bash if bash is not already installed and it will ask if you wish to use PKG or ports.

## django_setup.sh

Installs and setup of Django.

```bash
./django_setup.sh -u freebsdUser -e myenv -p myproject -s myWebsite.com
```

Django will use -u 'freebsdUser' as it's user. -e myenv will be the name of the python virtual environment. -p myproject will be the name of the project. -s myWebsite.com will be the domain or ip address of your Django website.
The script will ask you for these inputs if you do not provided or not all options are passed.

## drupal_setup.sh

Installs and setup of Drupal 7 using MySQL and Apache web server.

```sh
./drupal_setup.sh -u drupal_db_user -p drupalPass -d drupal_db -s myWebsite.com -P sqlPass
```

-u drupal_db_user is the user name that Drupal will use in the MySQL database. -p drupalPass is the password for the Drupal MySQL user. -d drupal_db the name to use when creating the MySQL database. -s myWebsite.com the domain or ip address of the Drupal website. -P sqlPass the root password for MySQL root user.

## drupal_uninstall.sh

Removes Drupal 7, MySQL and Apache.

```sh
./drupal_uninstall.sh
```

## drush_update.sh

Updates your Drupal install using drush.

```sh
./drush_update.sh /usr/local/www/drupal7
```

The script will take the pass directory and use drush to put drupal into maintenance mode and update all modules before return to normal mode and rebuild the cache.

## freebsd_setup.sh

Asks you questions about what packages you wish to install and setup

```sh
./freebsd_setup.sh -p -v -x -d lightdm -f -s -u richard -b richard -R
```

-p will use ports default is pkg. -v installs vmware tools. -x installs XFCE as your desktop manager. -d lightdm installs LightDM as your display manager. -f installs Firefox browser. -s installs sudo, -u richard adds user 'richard' to the sudo group. -b richard makes bash the default shell for user 'richard'. -R reboots the computer after excuting the script.

## freepbx_remove.sh

Work in progress script for removing FreePBX Phone system.

```sh
./freepbx_remove.sh
```

Removes freepbx and all the install pkg's.

## freepbx_setup.sh

Work in progress script for install FreePBX Phone system.

```sh
./freepbx_setup.sh
```

Will try and setup and install FreePBX.

## fusionpbx_setup.sh


