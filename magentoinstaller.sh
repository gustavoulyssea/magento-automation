#!/bin/bash

######################################
## Please set the following variables
######################################
## LOCAL DOMAIN NAME
DOMAIN="magento.localhost"
## MYSQL DATABASE
DB_NAME="magento"
## MYSQL USER
DB_USER="magento"
## EXISTING DATABASE DUMP FILE
DB_DUMP_FILENAME="magento.sql"
## SHOULD LINUX SERVICES (apache, mysql, php, elasticsearch) BE AUTOMATIC INSTALLED ? (answer no if already installed)
INSTALL_SERVICES="yes"
## SHOULD SSH KEYS BE CREATED TO THE CURRENT USER ? (answer no if you have already created id_rsa / ida_rsa.pub pair)
CREATE_SSH_KEYS="no"
######################################
CURRENT_USER=$(whoami)
if [ "$CURRENT_USER" != "root" ]
  then
       echo "Please run as root"
       exit 1
fi
DIRECTORY=$(pwd)
DB_PASS=$(echo $RANDOM | md5sum | head -c 20; echo)
UNIX_USER=$(logname)
APACHE_LOG_DIR="/var/log/apache2"

#### ASK BEFORE PROCEED

echo "Domain:        ${DOMAIN}"
echo "Database name: ${DB_USER}"
echo "Database user: ${DB_NAME}"
echo "DB Dump file:  ${DB_DUMP_FILENAME}"
echo ""
echo "Automatically install services: ${INSTALL_SERVICES}"
echo ""
echo "Automatically create SSH keys pair: ${CREATE_SSH_KEYS}"

echo "Please check configuration above before proceeding."
echo "Are you sure you want to proceed ? Please answer YES with capital letters."

read PROCEED

if [ "$PROCEED" != YES ]
then
  exit 0
fi

exit 0



if [ "$INSTALL_SERVICES" == "yes" ]
then
  echo "Updating apt-get database..."
  apt-get update
  echo "Install apache, mysql, git"
  if ! apt-get install -y apache2 mysql-server mysql-client git
  then
    echo "There was an error running apt-get install (services)"
    exit 1
  fi
  if ! apt-get install -y libapache2-mod-php7.3 php7.3-{common,cli,pdo,fpm,zip,gd,xml,mysql,cgi,gmp,curl,soap,bcmath,intl,mbstring,xmlrpc,mcrypt}
  then
    echo "There was an error running apt-get install (php7.3)"
    exit 1
  fi
  if ! apt-get install -y libapache2-mod-php7.4 php7.4-{common,cli,pdo,fpm,zip,gd,xml,mysql,cgi,gmp,curl,soap,bcmath,intl,mbstring,xmlrpc,mcrypt}
  then
    echo "There was an error running apt-get install (php7.4)"
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
mysql -e"CREATE DATABASE ${DB_NAME};"
echo "Create user '${DB_USER}'@'localhost'"
mysql -e"CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}'"
echo "Granting privileges"
mysql -e"GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost' WITH GRANT PRIVILEGES;FLUSH PRIVILEGES;"


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


echo "<?php
return [
    'cache_types' => [
        'compiled_config' => 1,
        'config' => 1,
        'layout' => 1,
        'block_html' => 1,
        'collections' => 1,
        'reflection' => 1,
        'db_ddl' => 1,
        'eav' => 1,
        'customer_notification' => 1,
        'config_integration' => 1,
        'config_integration_api' => 1,
        'full_page' => 1,
        'target_rule' => 1,
        'config_webservice' => 1,
        'translate' => 1,
        'vertex' => 1
    ],
    'backend' => [
        'frontName' => 'admin'
    ],
    'db' => [
        'connection' => [
            'indexer' => [
                'host' => 'localhost',
                'dbname' => 'cancaonova',
                'username' => 'camarao',
                'password' => 'praialinha',
                'active' => '1',
                'persistent' => null,
                'model' => 'mysql4',
                'engine' => 'innodb',
                'initStatements' => 'SET NAMES utf8;'
            ],
            'default' => [
                'host' => 'localhost',
                'dbname' => 'cancaonova',
                'username' => 'camarao',
                'password' => 'praialinha',
                'active' => '1',
                'driver_options' => [
                    1014 => false
                ],
                'model' => 'mysql4',
                'engine' => 'innodb',
                'initStatements' => 'SET NAMES utf8;'
            ]
        ],
        'table_prefix' => ''
    ],
    'crypt' => [
        'key' => '22b566f43b0b2a9b8dfbdf81819ae8ed'
    ],
    'resource' => [
        'default_setup' => [
            'connection' => 'default'
        ]
    ],
    'x-frame-options' => 'SAMEORIGIN',
    'MAGE_MODE' => 'developer',
    'session' => [
        'save' => 'files'
    ],
    'cache' => [
        'frontend' => [
            'default' => [
                'id_prefix' => '14a_'
            ],
            'page_cache' => [
                'id_prefix' => '14a_'
            ]
        ]
    ],
    'lock' => [
        'provider' => 'db',
        'config' => [
            'prefix' => ''
        ]
    ],
    'install' => [
        'date' => 'Fri, 04 Sep 2020 19:31:32 +0000'
    ],
    'remote_storage' => [
        'driver' => 'file'
    ],
    'queue' => [
        'consumers_wait_for_messages' => 1
    ]
];" > app/etc/env.php




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