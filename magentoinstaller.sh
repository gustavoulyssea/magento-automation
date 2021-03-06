#!/bin/bash

## @author Gustavo Ulyssea - gustavo.ulyssea@gmail.com
## @copyright Copyright (c) 2020-2022 GumNet (https://gum.net.br)
## @package Magento 2 automagic installation
## All rights reserved.
##
## Redistribution and use in source and binary forms, with or without
## modification, are permitted provided that the following conditions
## are met:
## 1. Redistributions of source code must retain the above copyright
##    notice, this list of conditions and the following disclaimer.
## 2. Redistributions in binary form must reproduce the above copyright
##    notice, this list of conditions and the following disclaimer in the
##    documentation and/or other materials provided with the distribution.
##
## THIS SOFTWARE IS PROVIDED BY GUM Net (https://gum.net.br). AND CONTRIBUTORS
## ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
## TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
## PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
## BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
## CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
## SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
## INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
## CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
## ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
## POSSIBILITY OF SUCH DAMAGE.
 
######################################
## ATTENTION THIS SCRIPT MUST BE RUN AS ROOT
######################################

######################################
## Please set the following variables
######################################
## LOCAL DOMAIN NAME
DOMAIN="magento.localhost"

## MYSQL DATABASE
DB_NAME="magento"

## MYSQL USER
DB_USER="magento"

## EXISTING DATABASE DUMP FILE - PLEASE ENTER THE FULL PATH
DB_DUMP_FILENAME="/root/magento.sql"

## GIT REPOSITORY ADDRESS ** Please do not add .git at the end of the line
GIT_REPOSITORY_URL="git@bitbucket.org:vendor/repository"

## BASE SYSTEM DIRECTORY WHERE VIRTUAL-HOST FILES ARE STORED - IN CASE OF DOUBT DO NOT MAKE CHANGES
WWW_BASEDIR="/var/www"

## SHOULD LINUX SERVICES (apache, mysql, php, elasticsearch) BE AUTOMATIC INSTALLED ? (answer no if already installed)
INSTALL_SERVICES="yes"

## SHOULD SSH KEYS BE CREATED TO THE CURRENT USER ? (answer no if you have already created id_rsa / ida_rsa.pub pair)
CREATE_SSH_KEYS="yes"
## PHP Version - IN CASE OF DOUBT DO NOT MAKE CHANGES
PHP_VERSION="7.4"
######################################

## Validate if user is root - user *MUST* be root - sudo is n00b
CURRENT_USER=$(whoami)
if [ "$CURRENT_USER" != "root" ]
  then
       echo "This script must be run as root"
       exit 1
fi
CURRENT_DIRECTORY=$(pwd)
DB_PASS=$(echo $RANDOM | md5sum | head -c 20; echo)
UNIX_USER=$(logname)
IFS='/' read -r -a array <<< "$GIT_REPOSITORY_URL"
REPOSITORY_NAME=${array[1]}
DIRECTORY="${WWW_BASEDIR}/${REPOSITORY_NAME}"

APACHE_LOG_DIR="/var/log/apache2"

#### Validation
if [ ! -f "$DB_DUMP_FILENAME" ]
then
  echo "Error - DB dump file not found. Please check the specified full path."
  exit 1
else
  echo "DB dump file is ready!"
fi

#### ASK BEFORE PROCEED
echo ""
echo ""
echo "Domain:        ${DOMAIN}"
echo "Database name: ${DB_USER}"
echo "Database user: ${DB_NAME}"
echo "DB Dump file:  ${DB_DUMP_FILENAME}"
echo "Git repository:${GIT_REPOSITORY_URL}"
echo "WWW directory: ${WWW_BASEDIR}"
echo ""
echo "Automatically install services: ${INSTALL_SERVICES}"
echo ""
echo "Automatically create SSH keys pair: ${CREATE_SSH_KEYS}"
echo ""
echo "Please check configuration above before proceeding."
echo ""
echo "Attention: *** This script was created for Ubuntu 20.04."
echo "               We cannot guarantee that it will work on other distributions."
echo ""
echo "           *** If you set CREATE_SSH_KEYS to YES existing id_rsa keys pair will be overwritten."
echo ""
read -p "Are you sure you want to proceed ? Please answer YES with capital letters: " PROCEED

if [ "$PROCEED" != YES ]
then
  exit 0
else
  echo ""
  echo "Starting..."
  echo ""
fi

if [ "$INSTALL_SERVICES" == "yes" ]
then
  echo "Add ppa:ondrej/php to apt"
  apt -y install software-properties-common
  add-apt-repository -y ppa:ondrej/php
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
  echo "Installing Elasticsearch..."
  apt-get -y install gnupg
  wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -
  apt-get -y install apt-transport-https
  echo "deb https://artifacts.elastic.co/packages/oss-6.x/apt stable main" | sudo tee  /etc/apt/sources.list.d/elastic-6.x.list
  apt-get update
  apt-get -y install openjdk-11-jdk
  apt-get -y install elasticsearch-oss
  sed -i 's/-Xms2g/-Xms512m/g' /etc/elasticsearch/jvm.options
  sed -i 's/-Xmx2g/-Xmx512m/g' /etc/elasticsearch/jvm.options
  service elasticsearch restart
else
  echo "Assuming apache, mysql, php7.4-fpm, elasticsearch are already installed."
  sleep 1
fi

if [ "$CREATE_SSH_KEYS" == "yes" ]
then
  echo ""
  echo "Creating ssh keys for user ${UNIX_USER}..."
  eval `ssh-agent -s`
  sudo -H -u "${UNIX_USER}" bash -c 'ssh-keygen -f ~/.ssh/id_rsa -P ""'
  ssh-add -D
  ssh-add
  echo ""
  echo "Please copy the following text (your public key) to your git provider configuration (do not include ---- lines)"
  echo "--------------------------------------------------------------------------"
  sudo -H -u "${UNIX_USER}" bash -c 'cat ~/.ssh/id_rsa.pub'
  echo "--------------------------------------------------------------------------"
  read -p "After copying the key please press enter to continue." LALA
fi



echo ""
echo "Creating database ${DB_NAME}"
mysql -e"CREATE DATABASE ${DB_NAME};"
echo ""
echo "Create user '${DB_USER}'@'localhost'"
mysql -e"CREATE USER '${DB_USER}'@'localhost' IDENTIFIED WITH mysql_native_password BY '${DB_PASS}'"
echo ""
echo "Granting privileges"
mysql -e"GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';FLUSH PRIVILEGES;"
echo "

log_bin_trust_function_creators = 1
" >> /etc/mysql/mysql.conf.d/mysqld.cnf
service mysql restart

echo ""
echo "Importing database from dump..."
mysql ${DB_NAME} < ${DB_DUMP_FILENAME}

echo "Entering www basedir..."
cd "$WWW_BASEDIR" || exit 1

echo "cloning git..."
IFS='@' read -r -a arraynew <<< "${array[0]}"
IFS=':' read -r -a arraytwo <<< "${arraynew[1]}"
GIT_DOMAIN=${arraytwo[0]}

ssh-keyscan "${GIT_DOMAIN}" >> ~/.ssh/known_hosts

if ! git clone $GIT_REPOSITORY_URL
then
  echo "Error cloning git."
  exit 1
fi
cd "${DIRECTORY}" || exit 1

echo "Downloading composer.phar"
wget https://github.com/gustavoulyssea/magento-automation/raw/master/composer.phar
php7.4 composer.phar global require hirak/prestissimo

echo "Entering magento installation homedir..."
cd "$DIRECTORY" || exit 1
echo "Runnning php composer.phar install..."
if ! php$PHP_VERSION composer.phar install
then
  "Error running php composer.phar install"
  exit 1
fi

echo "Create apache virtualhost...."
VIRTUALHOST="<VirtualHost *:80>
        ServerName ${DOMAIN}

        ServerAdmin webmaster@localhost
        DocumentRoot ${DIRECTORY}

<Directory ""${DIRECTORY}"">
    Options Indexes MultiViews FollowSymLinks
    AllowOverride All
    Require all granted
</Directory>

        ErrorLog ${APACHE_LOG_DIR}/${REPOSITORY_NAME}-error.log
        CustomLog ${APACHE_LOG_DIR}/${REPOSITORY_NAME}-access.log combined

</VirtualHost>"
## Use db name as virtualhost filename
echo "$VIRTUALHOST" > /etc/apache2/sites-available/${DB_NAME}.conf
ln -s /etc/apache2/sites-available/${DB_NAME}.conf /etc/apache2/sites-enabled/${DB_NAME}.conf
echo "Restarting apache..."
service apache2 restart

echo "Setting env.php directives..."

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
                'dbname' => '${DB_NAME}',
                'username' => '${DB_USER}',
                'password' => '${DB_PASS}',
                'active' => '1',
                'persistent' => null,
                'model' => 'mysql4',
                'engine' => 'innodb',
                'initStatements' => 'SET NAMES utf8;'
            ],
            'default' => [
                'host' => 'localhost',
                'dbname' => '${DB_NAME}',
                'username' => '${DB_USER}',
                'password' => '${DB_PASS}',
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
chmod ugo+rx /usr/bin/compila
echo "Installation finished successfully!"