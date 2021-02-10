#!/usr/bin/env bash
#----
## @Synopsis    Install script for Centreon Web Front (CentWeb)
## @Copyright   Copyright 2008, Guillaume Watteeux
## @Copyright	Copyright 2008-2020, Centreon
## @license GPL : http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt
## Install script for Centreon Web Front (CentWeb)
#----
#----
## Centreon is developed with GPL Licence 2.0
##
## GPL License: http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt
##
## Developed by : Julien Mathis - Romain Le Merlus
## Contributors : Guillaume Watteeux - Maximilien Bersoult
##
## This program is free software; you can redistribute it and/or
## modify it under the terms of the GNU General Public License
## as published by the Free Software Foundation; either version 2
## of the License, or (at your option) any later version.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
##    For information : infos@centreon.com

# debug ?
#set -x

###### check space of tmp dir
check_tmp_disk_space
if [ "$?" -eq 1 ] ; then
  if [ "$silent_install" -eq 1 ] ; then
    purge_centreon_tmp_dir "silent"
  else
    purge_centreon_tmp_dir
  fi
fi

# Checking requirements
echo -e "\n"
echo_info "$(gettext "Checking requirements")"
echo -e "$line"

## Locate PHP
locate_php_bin

## Check PHP version
check_php_version
if [ "$?" -eq 1 ] ; then
    echo_info "\n\t$(gettext "Your PHP version does not meet the requirements")"

    echo -e "\t$(gettext "Please read the documentation available here") : documentation.centreon.com"
    echo -e "\n\t$(gettext "Installation aborted")"

    purge_centreon_tmp_dir
    exit 1
fi

## Check composer dependencies (if vendor directory exists)
check_composer_dependencies
if [ "$?" -eq 1 ] ; then
    echo_info "\n\t$(gettext "You must first install the Composer's dependencies")"

    echo -e "\n\t$(gettext "composer install --no-dev --optimize-autoloader")"
    echo -e "\t$(gettext "Please read the documentation available here") : documentation.centreon.com"

    echo -e "\n\t$(gettext "Installation aborted")"
    purge_centreon_tmp_dir
    exit 1
fi

## Check frontend application (if www/static directory exists)
check_frontend_application
if [ "$?" -eq 1 ] ; then
    echo_info "\n\t$(gettext "You must first build the frontend application")"

    echo -e "\n\t$(gettext "Using npm install and then npm build")"
    echo -e "\t$(gettext "Please read the documentation available here") : documentation.centreon.com"

    echo -e "\n\t$(gettext "Installation aborted")"
    purge_centreon_tmp_dir
    exit 1
fi

locate_pear
locate_rrdtool
locate_mail
locate_cron_d
locate_logrotate_d
locate_perl

pear_module="0"
first=1
while [ "$pear_module" -eq 0 ] ; do
    check_pear_module "$INSTALL_VARS_DIR/$PEAR_MODULES_LIST"
    if [ "$?" -ne 0 ] ; then
            if [ "${PEAR_AUTOINST:-0}" -eq 0 ]; then
                if [ "$first" -eq 0 ] ; then
                    echo_info "$(gettext "Unable to upgrade PEAR modules. You seem to have a connection problem.")"
                fi
                yes_no_default "$(gettext "Do you want to install/upgrade your PEAR modules")" "$yes"
                [ "$?" -eq 0 ] && PEAR_AUTOINST=1
            fi
        if [ "${PEAR_AUTOINST:-0}" -eq 1 ] ; then
            upgrade_pear_module "$INSTALL_VARS_DIR/$PEAR_MODULES_LIST"
            install_pear_module "$INSTALL_VARS_DIR/$PEAR_MODULES_LIST"
            PEAR_AUTOINST=0
            first=0
        else
            pear_module="1"
        fi
    else
        echo_success "$(gettext "All PEAR modules")" "$ok"
        pear_module="1"
    fi
done

## Centreon information
echo -e "\n"
echo_info "$(gettext "Centreon information")"
echo -e "$line"

# Check Gorgone installation
# yes_no_default "$(gettext "Is the Gorgone module installed?")"
# if [ "$?" -ne 0 ] ; then
#     echo_failure "\n$(gettext "Gorgone is required.\nPlease install it before launching this script")" "$fail"
#     echo -e "\n\t$(gettext "Please read the documentation to manage the Gorgone daemon installation")"
#     echo -e "\t$(gettext "Available on github") : https://github.com/centreon/centreon-gorgone"
#     echo -e "\t$(gettext "or on the centreon documentation") : https://documentation.centreon.com/\n"
#     exit 1
# fi

## Ask for Centreon info
locate_centreon_installdir
locate_centreon_varlib
check_centreon_group
check_centreon_user
locate_centreon_etcdir
locate_centreon_logdir
locate_centreon_bindir
locate_centreon_generationdir
locate_centreon_rundir
locate_centreon_rrddir

### Trapd
locate_snmp_etcdir
locate_init_d
locate_centreontrapd_bindir

## Config Apache
echo -e "\n"
echo_info "$(gettext "Apache information")"
echo -e "$line"
check_user_apache
check_group_apache
check_apache_directory

## Config PHP FPM
check_php_fpm_directory

## Ask for Gorgone info
echo -e "\n"
echo_info "$(gettext "Gorgone information")"
echo -e "$line"
check_gorgone_user
locate_gorgone_varlib
locate_gorgone_config

## Ask for Engine user
echo -e "\n"
echo_info "$(gettext "Engine information")"
echo -e "$line"
check_engine_user
locate_engine_etc
locate_engine_log
locate_engine_lib
locate_engine_bin

## Ask for Broker user
echo -e "\n"
echo_info "$(gettext "Broker information")"
echo -e "$line"
check_broker_user
locate_broker_etc
# locate_broker_log
# locate_broker_lib
locate_broker_mod

## Ask for plugins directory
echo -e "\n"
echo_info "$(gettext "Plugins information")"
echo -e "$line"
locate_plugindir
locate_centreon_plugins
locate_centplugins_tmpdir

## Add default value for centreon engine connector
if [ -z "$CENTREON_ENGINE_CONNECTORS" ]; then
    if [ "$(uname -i)" = "x86_64" ]; then
        CENTREON_ENGINE_CONNECTORS="/usr/lib64/centreon-connector"
    else
        CENTREON_ENGINE_CONNECTORS="/usr/lib/centreon-connector"
    fi
fi

## Print all information
echo -e "\n"
echo_info "$(gettext "Information summary")"
echo -e "$line"
echo_info "$(gettext "Centreon installation directory:")" "$INSTALL_DIR_CENTREON"
echo_info "$(gettext "Centreon configuration directory:")" "$CENTREON_ETC"
echo_info "$(gettext "Centreon log directory:")" "$CENTREON_LOG"
echo_info "$(gettext "Centreon variable library directory:")" "$CENTREON_VARLIB"
echo_info "$(gettext "Centreon cache directory:")" "$CENTREON_CACHEDIR"
echo_info "$(gettext "Centreon run directory:")" "$CENTREON_RUNDIR"
echo_info "$(gettext "Centreon RRD directories:")" "$CENTSTORAGE_RRD"
echo_info "$(gettext "Engine configuration directory:")" "$ENGINE_ETC"
echo_info "$(gettext "Engine log directory:")" "$ENGINE_LOG"
echo_info "$(gettext "Engine library directory:")" "$ENGINE_LIB"
echo_info "$(gettext "Engine's binary:")" "$ENGINE_BINARY"
echo_info "$(gettext "Broker configuration directory:")" "$BROKER_ETC"
# echo_info "$(gettext "Broker variable library directory:")" "$BROKER_LIB"
# echo_info "$(gettext "Broker log directory:")" "$BROKER_LOG"
echo_info "$(gettext "Broker module:")" "$BROKER_MOD"
echo_info "$(gettext "Gorgone configuration directory:")" "$GORGONE_CONFIG"
echo_info "$(gettext "Gorgone variable library directory:")" "$GORGONE_VARLIB"
echo_info "$(gettext "Centreon Plugins directory")" "$CENTREON_PLUGINS"
echo_info "$(gettext "Centreon Plugins temporary directory")" "$CENTPLUGINS_TMP"
echo_info "$(gettext "Nagios Plugins directory:")" "$PLUGIN_DIR"

yes_no_default "$(gettext "Proceed to installation?")"
if [ "$?" -ne 0 ] ; then
    echo_info "$(gettext "Exiting")"
    exit 1
fi

## Disconnect user if upgrade
if [ "$upgrade" = "1" ]; then
    echo_info "$(gettext "Disconnect users from WebUI")"
    php $INSTALL_DIR/clean_session.php "$CENTREON_ETC" >> "$LOG_FILE" 2>&1
    check_result $? "$(gettext "All users are disconnected")"
fi

## Create a random APP_SECRET key
HEX_KEY=($(dd if=/dev/urandom bs=32 count=1 status=none | $PHP_BIN -r "echo bin2hex(fread(STDIN, 32));"))
echo -e "\n"
echo_info "$(gettext "Generated random key: $HEX_KEY")"
log "INFO" "$(gettext "Generated a random key") : $HEX_KEY"

## Step 1: Copy files to temporary directory
echo -e "\n"
echo_info "$(gettext "Step 1: Copy files to temporary directory")"
echo -e "$line"

## Create temporary folder and copy all sources into it
copy_in_tmp_dir 2>>$LOG_FILE

## Step 2: Prepare files
echo -e "\n"
echo_info "$(gettext "Step 2: Prepare files")"
echo -e "$line"

### Change macros for insertBaseConf.sql
log "INFO" "$(gettext "Change macros for insertBaseConf.sql")"
${SED} -i -e 's|@INSTALL_DIR_CENTREON@|'"$INSTALL_DIR_CENTREON"'|g' \
    -e 's|@BIN_MAIL@|'"$BIN_MAIL"'|g' \
    -e 's|@CENTREON_ETC@|'"$CENTREON_ETC"'|g' \
    -e 's|@CENTREON_LOG@|'"$CENTREON_LOG"'|g' \
    -e 's|@CENTREON_VARLIB@|'"$CENTREON_VARLIB"'|g' \
    -e 's|@BIN_RRDTOOL@|'"$BIN_RRDTOOL"'|g' \
    $TMP_DIR/source/www/install/insertBaseConf.sql
check_result $? "$(gettext "Change macros for 'insertBaseConf.sql'")"

${SED} -i -e 's|@CENTSTORAGE_RRD@|'"$CENTSTORAGE_RRD"'|g' \
	$TMP_DIR/source/www/install/createTablesCentstorage.sql
check_result $? "$(gettext "Change macros for 'createTablesCentstorage.sql'")"

### Change macros for SQL update files
macros="@CENTREON_ETC@,@CENTREON_CACHEDIR@,@CENTPLUGINSTRAPS_BINDIR@,@CENTREON_LOG@,@CENTREON_VARLIB@,@CENTREON_ENGINE_CONNECTORS@"
find_macros_in_dir "$macros" "$TMP_DIR/source/" "www" "Update*.sql" "file_sql_temp"

flg_error=0
${CAT} "$file_sql_temp" | while read file ; do
    log "MACRO" "$(gettext "Change macro for") : $file"
    ${SED} -i -e 's|@CENTREON_ETC@|'"$CENTREON_ETC"'|g' \
        -e 's|@CENTREON_CACHEDIR@|'"$CENTREON_CACHEDIR"'|g' \
        -e 's|@CENTPLUGINSTRAPS_BINDIR@|'"$CENTPLUGINSTRAPS_BINDIR"'|g' \
        -e 's|@CENTREON_VARLIB@|'"$CENTREON_VARLIB"'|g' \
        -e 's|@CENTREON_LOG@|'"$CENTREON_LOG"'|g' \
        -e 's|@CENTREON_ENGINE_CONNECTORS@|'"$CENTREON_ENGINE_CONNECTORS"'|g' \
        $TMP_DIR/source/$file
        [ $? -ne 0 ] && flg_error=1
    log "MACRO" "$(gettext "Copy in final dir") : $file"
done
check_result $flg_error "$(gettext "Change macros for SQL update files")"

### Change macros for PHP files
macros="@CENTREON_ETC@,@CENTREON_CACHEDIR@,@CENTPLUGINSTRAPS_BINDIR@,@CENTREON_LOG@,@CENTREON_VARLIB@,@CENTREONTRAPD_BINDIR@,@PHP_BIN@,%APP_SECRET%"
find_macros_in_dir "$macros" "$TMP_DIR/source/" "config" "*.php*" "file_php_config_temp"
find_macros_in_dir "$macros" "$TMP_DIR/source/" "." ".env*" "file_env_temp"
find_macros_in_dir "$macros" "$TMP_DIR/source/" "www" "*.php" "file_php_temp"
find_macros_in_dir "$macros" "$TMP_DIR/source/" "bin" "*" "file_bin_temp"
log "INFO" "$(gettext "Apply macros on PHP files")"

flg_error=0
${CAT} "$file_php_config_temp" "$file_env_temp" "$file_php_temp" "$file_bin_temp" | while read file ; do
        log "MACRO" "$(gettext "Change macro for") : $file"
        ${SED} -i -e 's|@CENTREON_ETC@|'"$CENTREON_ETC"'|g' \
                -e 's|@CENTREON_CACHEDIR@|'"$CENTREON_CACHEDIR"'|g' \
                -e 's|@CENTPLUGINSTRAPS_BINDIR@|'"$CENTPLUGINSTRAPS_BINDIR"'|g' \
                -e 's|@CENTREONTRAPD_BINDIR@|'"$CENTREON_BINDIR"'|g' \
                -e 's|@CENTREON_VARLIB@|'"$CENTREON_VARLIB"'|g' \
                -e 's|@CENTREON_LOG@|'"$CENTREON_LOG"'|g' \
                -e 's|@PHP_BIN@|'"$PHP_BIN"'|g' \
                -e 's|%APP_SECRET%|'"$HEX_KEY"'|g' \
                $TMP_DIR/source/$file
                [ $? -ne 0 ] && flg_error=1
        log "MACRO" "$(gettext "Copy in final dir") : $file"
done
check_result $flg_error "$(gettext "Change macros for PHP files")"

### Change macros for Perl files
macros="@CENTREON_ETC@,@CENTREON_CACHEDIR@,@CENTPLUGINSTRAPS_BINDIR@,@CENTREON_LOG@,@CENTREON_VARLIB@,@CENTREONTRAPD_BINDIR@"
find_macros_in_dir "$macros" "$TMP_DIR/source/" "bin/" "*" "file_perl_temp"

flg_error=0
${CAT} "$file_perl_temp" | while read file ; do
        log "MACRO" "$(gettext "Change macro for") : $file"
        ${SED} -i -e 's|@CENTREON_ETC@|'"$CENTREON_ETC"'|g' \
                -e 's|@CENTREON_CACHEDIR@|'"$CENTREON_CACHEDIR"'|g' \
                -e 's|@CENTPLUGINSTRAPS_BINDIR@|'"$CENTPLUGINSTRAPS_BINDIR"'|g' \
                -e 's|@CENTREONTRAPD_BINDIR@|'"$CENTREON_BINDIR"'|g' \
                -e 's|@CENTREON_VARLIB@|'"$CENTREON_VARLIB"'|g' \
                -e 's|@CENTREON_LOG@|'"$CENTREON_LOG"'|g' \
                $TMP_DIR/source/$file
                [ $? -ne 0 ] && flg_error=1
        log "MACRO" "$(gettext "Copy in final dir") : $file"
done
check_result $flg_error "$(gettext "Change macros for Perl files")"

### Change macros for centAcl.php
log "INFO" "$(gettext "Change macros for centAcl.php")"
${SED} -i -e 's|@CENTREON_ETC@|'"$CENTREON_ETC"'|g' \
    -e 's|@PHP_BIN@|'"$PHP_BIN"'|g' \
    $TMP_DIR/source/cron/centAcl.php
check_result $? "$(gettext "Change macros for 'centAcl.php'")"

### Change macros for downtimeManager.php
log "INFO" "$(gettext "Change macros for downtimeManager.php")"
${SED} -i -e 's|@CENTREON_ETC@|'"$CENTREON_ETC"'|g' \
    -e 's|@CENTREON_VARLIB@|'"$CENTREON_VARLIB"'|g' \
    -e 's|@PHP_BIN@|'"$PHP_BIN"'|g' \
    $TMP_DIR/source/cron/downtimeManager.php
check_result $? "$(gettext "Change macros for 'downtimeManager.php'")"

### Change macros for centreon-backup.pl
log "INFO" "$(gettext "Change macros for centreon-backup.pl")"
${SED} -i -e 's|@CENTREON_ETC@|'"$CENTREON_ETC"'|g' \
    -e 's|@PHP_BIN@|'"$PHP_BIN"'|g' \
    $TMP_DIR/source/cron/centreon-backup.pl
check_result $? "$(gettext "Change macros for 'centreon-backup.pl'")"

### Change macros for Centreon cron
log "INFO" "$(gettext "Change macros for centreon.cron")"
${SED} -i -e 's|@PHP_BIN@|'"$PHP_BIN"'|g' \
    -e 's|@PERL_BIN@|'"$BIN_PERL"'|g' \
    -e 's|@CENTREON_ETC@|'"$CENTREON_ETC"'|g' \
    -e 's|@INSTALL_DIR_CENTREON@|'"$INSTALL_DIR_CENTREON"'|g' \
    -e 's|@CENTREON_LOG@|'"$CENTREON_LOG"'|g' \
    -e 's|@CENTREON_USER@|'"$CENTREON_USER"'|g' \
    -e 's|@WEB_USER@|'"$WEB_USER"'|g' \
    $TMP_DIR/source/tmpl/install/centreon.cron
check_result $? "$(gettext "Change macros for cron/centreon file")"

log "INFO" "$(gettext "Change macros for centstorage.cron")"
${SED} -i -e 's|@PHP_BIN@|'"$PHP_BIN"'|g' \
	-e 's|@CENTSTORAGE_BINDIR@|'"$CENTSTORAGE_BINDIR"'|g' \
	-e 's|@INSTALL_DIR_CENTREON@|'"$INSTALL_DIR_CENTREON"'|g' \
	-e 's|@CENTREON_LOG@|'"$CENTREON_LOG"'|g' \
	-e 's|@CENTREON_ETC@|'"$CENTREON_ETC"'|g' \
	-e 's|@CENTREON_USER@|'"$CENTREON_USER"'|g' \
	-e 's|@WEB_USER@|'"$WEB_USER"'|g' \
    $TMP_DIR/source/tmpl/install/centstorage.cron
check_result $? "$(gettext "Change macros for cron/centstorage file")"

### Change macros for Centreon logrotate
log "INFO" "$(gettext "Change macros for centreon.logrotate")"
${SED} -i -e 's|@CENTREON_LOG@|'"$CENTREON_LOG"'|g' \
    $TMP_DIR/source/logrotate/centreon
check_result $? "$(gettext "Change macros for logrotate file")"

## Step 3: Copy files to final directory
echo -e "\n"
echo_info "$(gettext "Step 3: Copy files to final directory")"
echo -e "$line"

### Configuration directory
$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$CENTREON_USER" -g "$CENTREON_GROUP" \
    -d 775 \
    "$CENTREON_ETC" >> "$LOG_FILE" 2>&1
check_result $? "$(gettext "Install '$CENTREON_ETC/'")"

$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$CENTREON_USER" -g "$CENTREON_GROUP" \
    -m 644 \
    $TMP_DIR/source/www/install/var/config.yaml \
    $CENTREON_ETC/config.yaml >> "$LOG_FILE" 2>&1
check_result $? "$(gettext "Install '$CENTREON_ETC/config.yaml'")"

$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$CENTREON_USER" -g "$CENTREON_GROUP" \
    -d 775 \
    $CENTREON_ETC/config.d >> "$LOG_FILE" 2>&1
check_result $? "$(gettext "Install '$CENTREON_ETC/config.d/'")"

### Log directory
$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$CENTREON_USER" -g "$CENTREON_GROUP" \
    -d 775 \
    "$CENTREON_LOG" >> "$LOG_FILE" 2>&1
check_result $? "$(gettext "Install '$CENTREON_LOG/'")"

### Installs directory
$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$CENTREON_USER" -g "$CENTREON_GROUP" \
    -d 775 \
    "$CENTREON_VARLIB/" >> "$LOG_FILE" 2>&1
check_result $? "$(gettext "Install '$CENTREON_VARLIB/'")"

$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$CENTREON_USER" -g "$CENTREON_GROUP" \
    -d 775 \
    "$CENTREON_VARLIB/installs" >> "$LOG_FILE" 2>&1
check_result $? "$(gettext "Install '$CENTREON_VARLIB/installs/'")"

### RRD directories
$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$CENTREON_USER" -g "$CENTREON_GROUP" \
    -d 775 \
    "$CENTSTORAGE_RRD/status/" >> "$LOG_FILE" 2>&1
check_result $? "$(gettext "Install '$CENTSTORAGE_RRD/status/'")"

$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$CENTREON_USER" -g "$CENTREON_GROUP" \
    -d 775 \
    "$CENTSTORAGE_RRD/metrics/" >> "$LOG_FILE" 2>&1
check_result $? "$(gettext "Install '$CENTSTORAGE_RRD/metrics/'")"

### Centreon Plugins directory
$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$ENGINE_USER" -g "$ENGINE_GROUP" \
    -d 775 \
    "$CENTPLUGINS_TMP/" >> "$LOG_FILE" 2>&1
check_result $? "$(gettext "Install '$CENTPLUGINS_TMP/'")"

### Run directory
$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$CENTREON_USER" -g "$CENTREON_GROUP" \
    -d 750 \
	"$CENTREON_RUNDIR" >> "$LOG_FILE" 2>&1
check_result $? "$(gettext "Install '$CENTREON_RUNDIR/'")"

### Web directory
$INSTALL_DIR/cinstall $cinstall \
    -u "$CENTREON_USER" -g "$CENTREON_GROUP" \
    -d 775 \
    $INSTALL_DIR_CENTREON/www >> "$LOG_FILE" 2>&1

$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$CENTREON_USER" -g "$CENTREON_GROUP" \
    -d 755 -m 644 \
    -p $TMP_DIR/source/www \
    $TMP_DIR/source/www/* \
    $INSTALL_DIR_CENTREON/www/ >> "$LOG_FILE" 2>&1
check_result $? "$(gettext "Install '$INSTALL_DIR_CENTREON/www/'")"

### Sources
$INSTALL_DIR/cinstall $cinstall \
    -u "$CENTREON_USER" -g "$CENTREON_GROUP" \
    -d 775 \
    $INSTALL_DIR_CENTREON/src >> "$LOG_FILE" 2>&1

$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$WEB_USER" -g "$WEB_GROUP" \
    -d 755 -m 644 \
    $TMP_DIR/source/src/* \
    $INSTALL_DIR_CENTREON/src/ >> "$LOG_FILE" 2>&1
check_result $? "$(gettext "Install '$INSTALL_DIR_CENTREON/src/'")"

### API files
$INSTALL_DIR/cinstall $cinstall \
    -u "$CENTREON_USER" -g "$CENTREON_GROUP" \
    -d 775 \
    $INSTALL_DIR_CENTREON/api >> "$LOG_FILE" 2>&1

$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$WEB_USER" -g "$WEB_GROUP" \
    -d 755 -m 644 \
    $TMP_DIR/source/api/* \
    $INSTALL_DIR_CENTREON/api/ >> "$LOG_FILE" 2>&1
check_result $? "$(gettext "Install '$INSTALL_DIR_CENTREON/api/'")"

### Extra directories
[ ! -d "$INSTALL_DIR_CENTREON/www/modules" ] && \
    $INSTALL_DIR/cinstall $cinstall_opts \
        -u "$CENTREON_USER" -g "$CENTREON_GROUP" \
        -d 755 \
        $INSTALL_DIR_CENTREON/www/modules >> "$LOG_FILE" 2>&1 && \
        check_result $? "$(gettext "Install '$INSTALL_DIR_CENTREON/www/modules'")"

[ ! -d "$INSTALL_DIR_CENTREON/www/img/media" ] && \
    $INSTALL_DIR/cinstall $cinstall_opts \
        -u "$CENTREON_USER" -g "$CENTREON_GROUP" \
        -d 775 \
        $INSTALL_DIR_CENTREON/www/img/media >> "$LOG_FILE" 2>&1 && \
        check_result $? "$(gettext "Install '$INSTALL_DIR_CENTREON/www/img/media'")"

### Bases
$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$WEB_USER" -g "$WEB_GROUP" \
    -m 644 \
    $TMP_DIR/source/bootstrap.php $INSTALL_DIR_CENTREON/bootstrap.php >> "$LOG_FILE" 2>&1
check_result $? "$(gettext "Install '$INSTALL_DIR_CENTREON/bootstrap.php'")"

$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$WEB_USER" -g "$WEB_GROUP" \
    -m 644 \
    $TMP_DIR/source/.env $INSTALL_DIR_CENTREON/.env >> "$LOG_FILE" 2>&1
check_result $? "$(gettext "Install '$INSTALL_DIR_CENTREON/.env'")"

$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$WEB_USER" -g "$WEB_GROUP" \
    -m 644 \
    $TMP_DIR/source/.env.local.php $INSTALL_DIR_CENTREON/.env.local.php >> "$LOG_FILE" 2>&1
check_result $? "$(gettext "Install '$INSTALL_DIR_CENTREON/.env.local.php'")"

$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$WEB_USER" -g "$WEB_GROUP" \
    -m 644 \
    $TMP_DIR/source/container.php $INSTALL_DIR_CENTREON/container.php >> "$LOG_FILE" 2>&1
check_result $? "$(gettext "Install '$INSTALL_DIR_CENTREON/container.php'")"

### Composer
$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$WEB_USER" -g "$WEB_GROUP" \
    -m 644 \
    $TMP_DIR/source/composer.json $INSTALL_DIR_CENTREON/composer.json >> "$LOG_FILE" 2>&1
check_result $? "$(gettext "Install '$INSTALL_DIR_CENTREON/composer.json'")"

### npms
$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$WEB_USER" -g "$WEB_GROUP" \
    -m 644 \
    $TMP_DIR/source/package.json $INSTALL_DIR_CENTREON/package.json >> "$LOG_FILE" 2>&1
check_result $? "$(gettext "Install '$INSTALL_DIR_CENTREON/package.json'")"

$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$WEB_USER" -g "$WEB_GROUP" \
    -m 644 \
    $TMP_DIR/source/package-lock.json \
    $INSTALL_DIR_CENTREON/package-lock.json >> "$LOG_FILE" 2>&1
check_result $? "$(gettext "Install '$INSTALL_DIR_CENTREON/package-lock.json'")"

### Symfony config directories
$INSTALL_DIR/cinstall $cinstall \
    -u "$CENTREON_USER" -g "$CENTREON_GROUP" \
    -d 775 \
    $INSTALL_DIR_CENTREON/vendor >> "$LOG_FILE" 2>&1

$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$WEB_USER" -g "$WEB_GROUP" \
    -d 755 -m 644 \
    $TMP_DIR/source/vendor/* \
    $INSTALL_DIR_CENTREON/vendor/ >> "$LOG_FILE" 2>&1
check_result $? "$(gettext "Install '$INSTALL_DIR_CENTREON/vendor/'")"

$INSTALL_DIR/cinstall $cinstall \
    -u "$CENTREON_USER" -g "$CENTREON_GROUP" \
    -d 775 \
    $INSTALL_DIR_CENTREON/config >> "$LOG_FILE" 2>&1

$INSTALL_DIR/cinstall $cinstall \
    -u "$WEB_USER" -g "$WEB_GROUP" \
    -d 755 -m 644 \
    $TMP_DIR/source/config/* \
    $INSTALL_DIR_CENTREON/config/ >> "$LOG_FILE" 2>&1
check_result $? "$(gettext "Install '$INSTALL_DIR_CENTREON/config/'")"

### Smarty directories
$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$CENTREON_USER" -g "$CENTREON_GROUP" \
    -d 755 -m 664 \
    $TMP_DIR/source/GPL_LIB/* \
    $INSTALL_DIR_CENTREON/GPL_LIB/ >> "$LOG_FILE" 2>&1
check_result $? "$(gettext "Install '$INSTALL_DIR_CENTREON/GPL_LIB/'")"

### Install Centreon binaries
$INSTALL_DIR/cinstall $cinstall_opts \
    -m 755 \
    $TMP_DIR/source/bin/* \
    $CENTREON_BINDIR/ >> $LOG_FILE 2>&1
check_result $? "$(gettext "Install '$CENTREON_BINDIR/'")"

### Install libraries for Centreon CLAPI
$INSTALL_DIR/cinstall $cinstall \
    -u "$CENTREON_USER" -g "$CENTREON_GROUP" \
    -d 775 \
    $INSTALL_DIR_CENTREON/lib/Centreon >> "$LOG_FILE" 2>&1

$INSTALL_DIR/cinstall $cinstall_opts \
    -d 755 -m 664 \
    $TMP_DIR/source/lib/Centreon/* \
    $INSTALL_DIR_CENTREON/lib/Centreon/ >> $LOG_FILE 2>&1
check_result $? "$(gettext "Install '$INSTALL_DIR_CENTREON/lib/Centreon/'")"

### Cache directories
$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$CENTREON_USER" -g "$CENTREON_GROUP" \
    -d 775 \
    $CENTREON_CACHEDIR/config >> "$LOG_FILE" 2>&1
check_result $? "$(gettext "Install '$CENTREON_CACHEDIR/config/'")"

$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$CENTREON_USER" -g "$CENTREON_GROUP" \
    -d 775 \
    $CENTREON_CACHEDIR/config/engine >> "$LOG_FILE" 2>&1
check_result $? "$(gettext "Install '$CENTREON_CACHEDIR/config/engine/'")"

$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$CENTREON_USER" -g "$CENTREON_GROUP" \
    -d 775 \
    $CENTREON_CACHEDIR/config/broker >> "$LOG_FILE" 2>&1
check_result $? "$(gettext "Install '$CENTREON_CACHEDIR/config/broker/'")"

$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$CENTREON_USER" -g "$CENTREON_GROUP" \
    -d 775 \
    $CENTREON_CACHEDIR/config/export >> "$LOG_FILE" 2>&1
check_result $? "$(gettext "Install '$CENTREON_CACHEDIR/config/export/'")"

$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$CENTREON_USER" -g "$CENTREON_GROUP" \
    -d 775 \
    $CENTREON_CACHEDIR/symfony >> "$LOG_FILE" 2>&1
check_result $? "$(gettext "Install '$CENTREON_CACHEDIR/symfony/'")"

### Cron stuff
$INSTALL_DIR/cinstall $cinstall_opts \
    -m 644 \
    $TMP_DIR/source/tmpl/install/centreon.cron \
    $CRON_D/centreon >> "$LOG_FILE" 2>&1
check_result $? "$(gettext "Install '$CRON_D/centreon'")"

$INSTALL_DIR/cinstall $cinstall_opts \
    -m 644 \
    $TMP_DIR/source/tmpl/install/centstorage.cron \
    $CRON_D/centstorage >> "$LOG_FILE" 2>&1
check_result $? "$(gettext "Install '$CRON_D/centstorage'")"

### Cron binary
$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$CENTREON_USER" -g "$CENTREON_GROUP" \
    -d 755 -m 755 \
    $TMP_DIR/source/cron/* \
    $INSTALL_DIR_CENTREON/cron/ >> "$LOG_FILE" 2>&1
check_result $? "$(gettext "Install '$INSTALL_DIR_CENTREON/cron/'")"

### Logrotate
$INSTALL_DIR/cinstall $cinstall_opts \
    -m 644 \
    $TMP_DIR/source/logrotate/centreon \
    $LOGROTATE_D/centreon >> "$LOG_FILE" 2>&1
check_result $? "$(gettext "Install '$LOGROTATE_D/centreon'")"

### Install Centreon Perl lib
$INSTALL_DIR/cinstall $cinstall_opts \
    -d 755 -m 644 \
    $TMP_DIR/source/lib/perl/centreon/* \
    $PERL_LIB_DIR/centreon/ >> $LOG_FILE 2>&1
check_result $? "$(gettext "Install '$PERL_LIB_DIR/centreon/'")"

## Step 4: Configure Engine, Broker and Gorgone
echo -e "\n"
echo_info "$(gettext "Step 4: Configure Engine, Broker and Gorgone")"
echo -e "$line"

### Copy Pollers SSH keys (in case of upgrade) to the new "user" gorgone
if [ "$upgrade" = "1" ]; then
    copy_ssh_keys_to_gorgone
fi

### Create Gorgone Centreon specific configuration
${SED} -i -e 's|@CENTREON_ETC@|'"$CENTREON_ETC"'|g' \
    $TMP_DIR/source/www/install/var/gorgone/gorgoneRootConfigTemplate.yaml
check_result $? "$(gettext "Change macros for '30-centreon.yaml'")"

$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$GORGONE_USER" -g "$GORGONE_GROUP" \
    -m 644 \
    $TMP_DIR/source/www/install/var/gorgone/gorgoneRootConfigTemplate.yaml \
    $GORGONE_CONFIG/config.d/30-centreon.yaml >> "$LOG_FILE" 2>&1
check_result $? "$(gettext "Install '$GORGONE_CONFIG/config.d/30-centreon.yaml'")"

### Modify permissions on /etc/centreon-engine folder
flg_error=0
$INSTALL_DIR/cinstall $cinstall_opts \
    -g "$ENGINE_GROUP" \
    -d 775 \
    "$ENGINE_ETC" >> "$LOG_FILE" 2>&1
[ $? -ne 0 ] && flg_error=1

find "$ENGINE_ETC" -type f -print | \
    xargs -I '{}' ${CHMOD}  755 '{}' >> "$LOG_FILE" 2>&1
[ $? -ne 0 ] && flg_error=1
find "$ENGINE_ETC" -type f -print | \
    xargs -I '{}' ${CHOWN} "$ENGINE_USER":"$ENGINE_GROUP" '{}' >> "$LOG_FILE" 2>&1
[ $? -ne 0 ] && flg_error=1
check_result $flg_error "$(gettext "Modify rights on '$ENGINE_ETC'")"

### Modify rights to Broker /etc/centreon-broker folder
if [ "$ENGINE_ETC" != "$BROKER_ETC" ]; then
    $INSTALL_DIR/cinstall $cinstall_opts \
        -g "$BROKER_GROUP" -d 775 \
        "$BROKER_ETC" >> "$LOG_FILE" 2>&1
    [ $? -ne 0 ] && flg_error=1
    find "$BROKER_ETC" -type f -print | \
        xargs -I '{}' ${CHMOD}  775 '{}' >> "$LOG_FILE" 2>&1
    [ $? -ne 0 ] && flg_error=1
    find "$BROKER_ETC" -type f -print | \
        xargs -I '{}' ${CHOWN} "$BROKER_USER":"$BROKER_GROUP" '{}' >> "$LOG_FILE" 2>&1
    [ $? -ne 0 ] && flg_error=1
    check_result $flg_error "$(gettext "Modify rights on") '$BROKER_ETC'"
fi

## Step 5: Update groups memberships
echo -e "\n"
echo_info "$(gettext "Step 5: Update groups memberships")"
echo -e "$line"

add_group "$WEB_USER" "$CENTREON_GROUP"
add_group "$ENGINE_USER" "$CENTREON_GROUP"
get_primary_group "$ENGINE_USER" "ENGINE_GROUP"
add_group "$WEB_USER" "$ENGINE_GROUP"
add_group "$CENTREON_USER" "$ENGINE_GROUP"
add_group "$CENTREON_USER" "$WEB_GROUP"

if [ -z "$BROKER_USER" ]; then
    BROKER_USER=$ENGINE_USER
    get_primary_group "$BROKER_USER" "BROKER_GROUP"
else
    get_primary_group "$BROKER_USER" "BROKER_GROUP"
    add_group "$WEB_USER" "$BROKER_GROUP"
    add_group "$ENGINE_USER" "$BROKER_GROUP"
    add_group "$BROKER_USER" "$CENTREON_GROUP"
fi
get_primary_group "$GORGONE_USER" "GORGONE_GROUP"
add_group "$CENTREON_USER" "$GORGONE_GROUP"
add_group "$WEB_USER" "$GORGONE_GROUP"
add_group "$GORGONE_USER" "$CENTREON_GROUP"
add_group "$GORGONE_USER" "$BROKER_GROUP"
add_group "$GORGONE_USER" "$ENGINE_GROUP"
add_group "$GORGONE_USER" "$WEB_GROUP"

mkdir -p "$TMP_DIR/examples"

## Step 6: Configure Sudo
echo -e "\n"
echo_info "$(gettext "Step 6: Configure Sudo")"
echo -e "$line"
configure_sudo "$TMP_DIR/examples"

## Step 7: Configure Apache
echo -e "\n"
echo_info "$(gettext "Step 7: Configure Apache")"
echo -e "$line"
configure_apache "$TMP_DIR/examples"

## Step 8: Configure PHP FPM
echo -e "\n"
echo_info "$(gettext "Step 8: Configure PHP FPM")"
echo -e "$line"
configure_php_fpm "$TMP_DIR/examples"

# End
echo "\n$headerline"
echo -e "\t$(gettext "Create configuration and installation files")"
echo "$headerline"

## Create configfile for web install
createConfFile

## Write install config file
createCentreonInstallConf
createCentPluginsInstallConf
