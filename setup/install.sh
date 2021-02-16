#!/bin/bash

# Install EPEL repository (if needed)
yum -y install epel-release

# Install redis (if needed)
yum -y install redis

# Remount /tmp with execute permissions (only if /tmp partition exists and is read-only)
REMOUNT_TMP=false
if [ "$(mount | grep /tmp | grep noexec)" ]; then
    mount -o remount,exec /tmp

    REMOUNT_TMP=true
fi

# Install php-redis module (if not installed yet)
if [ ! "$(php -m | grep redis)" ]; then
    wget https://github.com/FriendsOfPHP/pickle/releases/latest/download/pickle.phar -O /tmp/pickle.phar
    php /tmp/pickle.phar install redis --defaults --save-logs
    rm /tmp/pickle.phar
fi

PHP_INI_FOLDER=$(php -r "echo PHP_CONFIG_FILE_SCAN_DIR;")

# Enable redis php extension in custom php.ini (if not enabled yet)
if [ ! -f "$PHP_INI_FOLDER/99-redis.ini" ]; then
    echo -e "\n; Redis\nextension=redis.so" >> "$PHP_INI_FOLDER/99-redis.ini"
fi

# Restart apache
systemctl restart httpd

# Remount /tmp with noexec permissions (if needed)
if [ "$REMOUNT_TMP" = true ] ; then
    mount -o remount,noexec /tmp
fi

# Create instances folder for redis instances
mkdir -p /etc/redis/instances

# Chown instances folder
chown -R redis.redis /etc/redis/instances

# Remove existing systemctl script
rm -f /lib/systemd/system/redis.service

# Copy new systemctl scripts
cp -a redis@.service /lib/systemd/system/
cp -a redis.service /lib/systemd/system/

# Reload systemctl daemons
systemctl daemon-reload

# Enable main service
systemctl enable redis.service

# Copy sudoers file
cp -a redis.sudoers /etc/sudoers.d/redis

# Fix sudoers file permissions
chown root.root /etc/sudoers.d/redis
