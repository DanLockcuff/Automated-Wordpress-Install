#!/bin/bash
#create_site and install wordpress
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

SED=`which sed`
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
SCRIPT_DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
#SCRIPT_DIR=`dirname $0`
#SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
MAIN_WEB_DIR='/www'
NGINX_SITES_DIR='/etc/nginx/sites'
PHP_POOL_DIR='/etc/php5/fpm/pool.d'

# NGINX_SITES_ENABLED='/usr/local/nginx/'
if [ -z $1 ]; then
    echo "No domain name given"
    exit 1
fi
DOMAIN=$1
TYPE=$2

# check the domain is roughly valid!
PATTERN="^([[:alnum:]]([[:alnum:]\-]{0,61}[[:alnum:]])?\.)+[[:alpha:]]{2,6}$"
if [[ "$DOMAIN" =~ $PATTERN ]]; then
    DOMAIN=`echo $DOMAIN | tr '[A-Z]' '[a-z]'`
    echo "Creating hosting for:" $DOMAIN
else
    echo "invalid domain name"
    exit 1
fi

#Replace dots with underscores
CLEAN_DOMAIN=`echo $DOMAIN | $SED 's/\./_/g'`
SITE_DIR=$CLEAN_DOMAIN
SITE_HTML_DIR="$SITE_DIR/htdocs"
SITE_LOG_DIR="$SITE_DIR/logs"

# Now we need to copy the virtual host template
CONFIG=$NGINX_SITES_DIR/$DOMAIN.conf
PHP_POOL=$PHP_POOL_DIR/$CLEAN_DOMAIN.conf

if [[ "$TYPE" == "wordpress" ]] ;then
    sudo cp $SCRIPT_DIR/templates/virtual_host_wordpress.template $CONFIG
else
    sudo cp $SCRIPT_DIR/templates/virtual_host.template $CONFIG
fi

sudo cp $SCRIPT_DIR/templates/php_pool.template $PHP_POOL

sudo $SED -i "s/CLEAN_DOMAIN/$CLEAN_DOMAIN/g" $CONFIG
sudo $SED -i "s/DOMAIN/$DOMAIN/g" $CONFIG
sudo $SED -i "s/ROOT_DIR/$SITE_DIR/g" $CONFIG
sudo $SED -i "s/$MAIN_WEB_DIR/$SITE_HTML_DIR/" $CONFIG
sudo $SED -i "s!LOG_DIR!$MAIN_WEB_DIR/$SITE_LOG_DIR!g" $CONFIG


sudo $SED -i "s/CLEAN_DOMAIN/$CLEAN_DOMAIN/g" $PHP_POOL

# set up web root
sudo mkdir -p $MAIN_WEB_DIR/$SITE_HTML_DIR
sudo mkdir -p $MAIN_WEB_DIR/$SITE_LOG_DIR

# if WP download and install
if [[ "$TYPE" == "wordpress" ]] ;then
    TEMP_FOLDER=/tmp/site_create
    mkdir $TEMP_FOLDER
    echo ''
    echo ''
    echo ''
    echo ''
    echo ''
    wget wordpress.org/latest.tar.gz -P $TEMP_FOLDER
    tar xf $TEMP_FOLDER/latest.tar.gz -C $TEMP_FOLDER
    cp -rf $TEMP_FOLDER/wordpress/*  $MAIN_WEB_DIR/$SITE_HTML_DIR/
    rm -rf $TEMP_FOLDER
#    rm -f latest.tar.gz
fi

sudo chmod 775 $MAIN_WEB_DIR/ -R
sudo chown www-data:www-data -R $MAIN_WEB_DIR/$SITE_HTML_DIR
sudo chown www-data:www-data -R $MAIN_WEB_DIR/$SITE_LOG_DIR
sudo chown www-data:www-data -R $MAIN_WEB_DIR/$SITE_LOG_DIR
sudo chown www-data:www-data $CONFIG
sudo chmod 775 $CONFIG

# create symlink to enable site
# sudo ln -s $CONFIG $NGINX_SITES_ENABLED/$DOMAIN.conf

# reload Nginx to pull in new config
#sudo systemctl restart nginx.service
sudo systemctl restart php7.1-fpm.service

if [[ "$TYPE" != "wordpress" ]] ;then
    # put the template index.html file into the new domains web dir
    sudo cp $SCRIPT_DIR/templates/index.html.template $MAIN_WEB_DIR/$SITE_HTML_DIR/index.html
    sudo $SED -i "s/SITE/$DOMAIN/g" $MAIN_WEB_DIR/$SITE_HTML_DIR/index.html
    sudo chown www-data:www-data $MAIN_WEB_DIR/$SITE_HTML_DIR/index.html
fi

echo "Site Created for $DOMAIN"