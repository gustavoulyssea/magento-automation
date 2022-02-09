#!/bin/bash

######################################
## Please set the following variables
######################################
DOMAIN="magento.localhost"
DB_NAME="magento"
DB_USER="magento"
DB_DUMP_FILENAME="magento.sql"
INSTALL_SERVICES="yes"
CREATE_SSH_KEYS="no"
######################################

if (whoami != root)
  then
       echo "Please run as root"
       exit 1
fi
DIRECTORY=$(pwd)
DB_PASS=$(echo $RANDOM | md5sum | head -c 20; echo)
APACHE_LOG_DIR="/var/log/apache2"
if [$INSTALL_SERVICES == "yes"]
then
  echo "Updating apt-get database..."
  apt-get update
  echo "Install apache, mysql, git"
  apt-get install -y apache2 mysql-server mysql-client git
  if [$? != 0]
  then
    exit 1
  fi
  apt-get install -y libapache2-mod-php7.3 php7.3-{common,cli,pdo,fpm,zip,gd,xml,mysql,cgi,gmp,curl,soap,bcmath,intl,mbstring,xmlrpc,mcrypt}
  if [$? != 0]
  then
    exit 1
  fi
  apt-get install -y libapache2-mod-php7.4 php7.4-{common,cli,pdo,fpm,zip,gd,xml,mysql,cgi,gmp,curl,soap,bcmath,intl,mbstring,xmlrpc,mcrypt}
  if [$? = yes]
  then
    exit 1
  fi
  echo "Installing magento-cloud client"
  curl -sS https://accounts.magento.cloud/cli/installer | php
  echo "Enabling mod_rewrite..."
  a2enmod rewrite
else
  echo "Assuming apache, mysql, php7.4-fpm, elasticsearch are already installed."
  sleep 1
fi

echo "Creating database ${DB_NAME}"
mysql -e"create database ${DB_NAME};"
echo "Create user '${DB_USER}'@'localhost'"
mysql -e"create user '${DB_USER}'@'localhost' identified by '${DB_PASS}'"
echo "Granting privileges"
mysql -e"grant all privileges on ${DB_NAME}.* to '${DB_USER}'@'localhost' with grant option;flush privileges;"

echo "Importing database from dump..."
mysql ${DB_NAME} < ${DB_DUMP_FILENAME}

echo "Create apache virtualhost...."
VIRTUALHOST="<VirtualHost *:80>
        ServerName ${DOMAIN}

        ServerAdmin webmaster@localhost
        DocumentRoot ${DIRECTORY}

<Directory "${DIRECTORY}">
    Options Indexes MultiViews FollowSymLinks
    AllowOverride All
    Require all granted
</Directory>

        ErrorLog ${APACHE_LOG_DIR}/${DIRECTORY}-error.log
        CustomLog ${APACHE_LOG_DIR}/${DIRECTORY}-access.log combined

</VirtualHost>"
## Use db name as virtualhost filename
echo $VIRTUALHOST > /etc/apache2/sites-available/${DB_NAME}.conf
ln -s /etc/apache2/sites-available/${DB_NAME}.conf /etc/apache2/sites-enabled/${DB_NAME}.conf
service apache2 restart

echo "Installing composer dependencies..."
php7.4 composer.phar install
echo "Setting env.php directives..."
bin/magento setup:config:set --db-user="${DB_USER}" --db-password="${DB_PASS}" --db-name="${DB_NAME}"
echo "Setting magento developer mode..."
bin/magento deploy:mode:set developer
echo "Running bin/magento setup:upgrade ..."
bin/magento setup:upgrade
echo "Running bin/magento setup:di:compile ..."
bin/magento setup:di:compile
echo "Changing owner to www-data:www-data...."
chown -R www-data:www-data .
echo "Assuring anyone can write..."
chmod -R ugo+rw .
find . -type d -exec chmod ugo+x {} \;

echo "Creating /usr/bin/compila..."
echo "rm -rf var/di var/generation var/generated/* var/cache/* var/log/* var/page_cache/* view_preprocessed/* pub/static/*

      bin/magento setup:di:compile
      bin/magento cache:flush

      chown -R www-data:www-data .
      chmod -R ugo+rw app
      chmod -R ugo+rw generated
      chmod -R ugo+rw lib
      chmod -R ugo+rw m2-hotfixes
      chmod -R ugo+rw pub
      chmod -R ugo+rw var
      chmod -R ugo+rw view_preprocessed
      find . -type d -exec chmod ugo+x {} \;
" > /usr/bin/compila