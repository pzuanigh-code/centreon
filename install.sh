#!/bin/bash
#----
## @Synopsis	Install Script for Centreon project
## @Copyright	Copyright 2008, Guillaume Watteeux
## @Copyright	Copyright 2008-2021, Centreon
## @License	GPL : http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt
## Centreon Install Script
## Use 
## <pre>
## Usage: sh install.sh [OPTION]
## Options:
##  -f	Input file with all variables define (use for with template)
##  -u	Input file with all variables define for update centreon
##  -v	Verbose mode
##  -h	print usage
## </pre>
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
#

#----
## Usage information for install.sh
## @Sdtout	Usage information
#----
usage() {
	local program=$0
	echo -e "Usage: $program -f <file>"
	echo -e "  -i\tinstall centreon"
	echo -e "  -f\tfile with all variable"
	echo -e "  -u\tupgrade centreon with specify your directory with instCent* files"
	echo -e "  -v\tverbose mode"
	exit 1
}

# define where is a centreon source 
BASE_DIR=$(dirname $0)
## set directory
BASE_DIR=$( cd $BASE_DIR; pwd )
export BASE_DIR
if [ -z "${BASE_DIR#/}" ] ; then
	echo -e "You cannot select the filesystem root folder"
	exit 1
fi
INSTALL_DIR="$BASE_DIR/install"
export INSTALL_DIR
PERL_LIB_DIR=`eval "\`perl -V:installvendorlib\`"; echo $installvendorlib`
# for freebsd
if [ "$PERL_LIB_DIR" = "" -o "$PERL_LIB_DIR" = "UNKNOWN" ]; then
    PERL_LIB_DIR=`eval "\`perl -V:installsitelib\`"; echo $installsitelib`
fi
# define a locale directory for use gettext (LC_MESSAGE)
TEXTDOMAINDIR=$BASE_DIR/locale
export TEXTDOMAINDIR
TEXTDOMAIN=install.sh
export TEXTDOMAIN

## log default vars 
. $INSTALL_DIR/vars

## Test if gettext was installed
# I use PATH variable to find
found="0"
OLDIFS="$IFS"
IFS=:
for p in $PATH ; do
	[ -x "$p/gettext" ] && found="1"
done
IFS=$OLDIFS
if [ $found -eq 1 ] ; then 
	. $INSTALL_DIR/gettext.sh
else
	# if not, use my gettext dummy :p
	PATH="$PATH:$INSTALL_DIR"
fi

## load all functions used in this script
. $INSTALL_DIR/functions

## Use TRAPs to call clean_and_exit when user press
## CRTL+C or exec kill -TERM.
trap clean_and_exit SIGINT SIGTERM

## Define a default log file
LOG_FILE=${LOG_FILE:=log\/install_centreon.log}

## Valid if you are root 
if [ "${FORCE_NO_ROOT:-0}" -ne 0 ]; then
	USERID=$(id -u)
	if [ "$USERID" != "0" ]; then
	    echo -e "You must launch this script using a root user"
	    exit 1
	fi
fi

_tmp_install_opts="0"
silent_install="0"
upgrade="0"
user_install_vars=""
inst_upgrade_dir=""
use_upgrade_files="0"

#define cinstall options
cinstall_opts=""

## Getopts :)
# When you use options, by default I set silent_install to 1.
while getopts "if:u:hv" Options
do
	case ${Options} in
		i )	silent_install="0"
			_tmp_install_opts="1"
			;;
		f )	silent_install="1"
			user_install_vars="${OPTARG}"
			_tmp_install_opts="1"
			;;
		u )	silent_install="1"
			inst_upgrade_dir="${OPTARG%/}"
			cinstall_opts="$cinstall_opts -f"
			upgrade="1" 
			_tmp_install_opts="1"
			;;
		v )	cinstall_opts="$cinstall_opts -v" 
			# need one variable to parse debug log 
			;;
		\?|h)	usage ; exit 0 ;;
		* )	usage ; exit 1 ;;
	esac
done

if [ "$_tmp_install_opts" -eq 0 ] ; then
	usage
	exit 1
fi

#Export variable for all programs
export silent_install user_install_vars CENTREON_CONF cinstall_opts inst_upgrade_dir upgrade

## init LOG_FILE
# backup old log file...
[ ! -d "$LOG_DIR" ] && mkdir -p "$LOG_DIR"
if [ -e "$LOG_FILE" ] ; then
	mv "$LOG_FILE" "$LOG_FILE.`date +%Y%m%d-%H%M%S`"
fi
# Clean (and create) my log file
${CAT} << __EOL__ > "$LOG_FILE"
__EOL__

# Init GREP,CAT,SED,CHMOD,CHOWN variables
define_specific_binary_vars

echo_info "Welcome to Centreon installation script!"
yes_no_default "Should we start?" "$yes"

## Test all binaries
BINARIES="rm cp mv ${CHMOD} ${CHOWN} echo more mkdir find ${GREP} ${CAT} ${SED}"

# Checking requirements
echo_title "Checking needed binaries for installation script"

binary_fail="0"
# For the moment, I check if all binary exists in path.
# After, I must look a solution to use complet path by binary
for binary in $BINARIES; do
	if [ ! -e ${binary} ] ; then 
		pathfind_ret "$binary" "PATH_BIN"
		if [ "$?" -eq 0 ] ; then
			echo_success "$PATH_BIN/${binary}" "$ok"
		else 
			echo_failure "${binary}" "$fail"
			log "ERR" "\$binary not found in \$PATH"
			binary_fail=1
		fi
	else
		echo_success "${binary}" "$ok"
	fi
done

# Script stop if one binary wasn't found
if [ "$binary_fail" -eq 1 ] ; then
	echo_info "Please check fail binary and retry"
	exit 1
fi

# When you exec this script without file, you must valid a GPL licence.
# if [ "$silent_install" -ne 1 ] ; then 
# 	echo -e "\nYou will now read Centreon Licence.\\n\\tPress enter to continue."
# 	read 
# 	tput clear 
# 	more "$BASE_DIR/LICENSE.md"

# 	yes_no_default "Do you accept GPL license ?" 
# 	if [ "$?" -ne 0 ] ; then 
# 		echo_info "As you did not accept the license, we cannot continue."
# 		log "INFO" "Installation aborted - License not accepted"
# 		exit 1
# 	else
# 		log "INFO" "Accepted the license"
# 	fi
# else 
# 	if [ "$upgrade" -eq 0 ] ; then
# 		. $user_install_vars
# 	fi
# fi

if [ "$upgrade" -eq 1 ] ; then
	# Test if instCent* file exist
	if [ "$(ls $inst_upgrade_dir/instCent* | wc -l )" -ge 1 ] ; then
		inst_upgrade_dir=${inst_upgrade_dir%/}
		echo_title "Detecting old installation"
		echo_success "Finding configuration file in: $inst_upgrade_dir" "$ok"
		log "INFO" "Old configuration found in  $(ls $inst_upgrade_dir/instCent*)"
		echo_info "You seem to have an existing Centreon.\n"
		yes_no_default "Do you want to use the last Centreon install parameters ?" "$yes"
		if [ "$?" -eq 0 ] ; then
			echo_passed "\nUsing:  $(ls $inst_upgrade_dir/instCent*)" "$ok"
			use_upgrade_files="1"
		fi
	fi
fi

if [ "$use_upgrade_files" -eq 1 ] ; then
    if [ -e "$inst_upgrade_dir/instCentWeb.conf" ] ; then
        log "INFO" "Load variables: $inst_upgrade_dir/instCentWeb.conf"
        . $inst_upgrade_dir/instCentWeb.conf
    fi
    if [ -e "$inst_upgrade_dir/instCentPlugins.conf" ] ; then
        log "INFO" "Load variables: $inst_upgrade_dir/instCentPlugins.conf"
        . $inst_upgrade_dir/instCentPlugins.conf
    fi
    if [ -n "$NAGIOS_USER" ] ; then
        echo_info "Convert variables for upgrade:"
        ENGINE_USER=$NAGIOS_USER
        [ -n "$NAGIOS_GROUP" ] && ENGINE_GROUP=$NAGIOS_GROUP
        [ -n "$NAGIOS_ETC" ] && ENGINE_ETC=$NAGIOS_ETC
        [ -n "$NAGIOS_BINARY" ] && ENGINE_BINARY=$NAGIOS_BINARY
    fi
fi

## Start installation

# Check space of tmp dir
check_tmp_disk_space
if [ "$?" -eq 1 ] ; then
  if [ "$silent_install" -eq 1 ] ; then
    purge_centreon_tmp_dir "silent"
  else
    purge_centreon_tmp_dir
  fi
fi

# Checking requirements
echo_title "Checking requirements"

## Locate PHP
locate_php_bin

## Check PHP version
check_php_version
if [ "$?" -eq 1 ] ; then
    echo_info "\n\tYour PHP version does not meet the requirements"

    echo -e "\tPlease read the documentation available here : documentation.centreon.com"
    echo -e "\n\tInstallation aborted"

    purge_centreon_tmp_dir
    exit 1
fi

## Check composer dependencies (if vendor directory exists)
check_composer_dependencies
if [ "$?" -eq 1 ] ; then
    echo_info "\n\tYou must first install the Composer's dependencies"

    echo -e "\n\tcomposer install --no-dev --optimize-autoloader"
    echo -e "\tPlease read the documentation available here : documentation.centreon.com"

    echo -e "\n\tInstallation aborted"
    purge_centreon_tmp_dir
    exit 1
fi

## Check frontend application (if www/static directory exists)
check_frontend_application
if [ "$?" -eq 1 ] ; then
    echo_info "\n\tYou must first build the frontend application"

    echo -e "\n\tUsing npm install and then npm build"
    echo -e "\tPlease read the documentation available here : documentation.centreon.com"

    echo -e "\n\tInstallation aborted"
    purge_centreon_tmp_dir
    exit 1
fi

locate_rrdtool
locate_mail
locate_cron_d
locate_logrotate_d
locate_perl

## Centreon information
echo_title "Centreon information"

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
locate_centreon_centcore

### Trapd
locate_snmp_etcdir
locate_init_d
locate_centreontrapd_bindir

## Config Apache
echo_title "Apache information"
check_user_apache
check_group_apache
check_apache_directory

## Config PHP FPM
check_php_fpm_directory

## Ask for Gorgone info
echo_title "Gorgone information"
check_gorgone_user
locate_gorgone_varlib
locate_gorgone_config

## Ask for Engine user
echo_title "Engine information"
check_engine_user
locate_engine_etc
locate_engine_log
locate_engine_lib
locate_engine_bin

## Ask for Broker user
echo_title "Broker information"
check_broker_user
locate_broker_etc
# locate_broker_log
# locate_broker_lib
locate_broker_mod

## Ask for plugins directory
echo_title "Plugins information"
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
echo_title "Information summary"
echo_info "Centreon installation directory:" "$INSTALL_DIR_CENTREON"
echo_info "Centreon configuration directory:" "$CENTREON_ETC"
echo_info "Centreon log directory:" "$CENTREON_LOG"
echo_info "Centreon variable library directory:" "$CENTREON_VARLIB"
echo_info "Centreon Centcore directory:" "$CENTREON_CENTCORE"
echo_info "Centreon cache directory:" "$CENTREON_CACHEDIR"
echo_info "Centreon run directory:" "$CENTREON_RUNDIR"
echo_info "Centreon RRD status directory:" "$CENTSTORAGE_RRD/status"
echo_info "Centreon RRD metrics directory:" "$CENTSTORAGE_RRD/metrics"
echo_info "Engine configuration directory:" "$ENGINE_ETC"
echo_info "Engine log directory:" "$ENGINE_LOG"
echo_info "Engine library directory:" "$ENGINE_LIB"
echo_info "Engine's binary:" "$ENGINE_BINARY"
echo_info "Broker configuration directory:" "$BROKER_ETC"
# echo_info "Broker variable library directory:" "$BROKER_LIB"
# echo_info "Broker log directory:" "$BROKER_LOG"
echo_info "Broker module:" "$BROKER_MOD"
echo_info "Gorgone configuration directory:" "$GORGONE_CONFIG"
echo_info "Gorgone variable library directory:" "$GORGONE_VARLIB"
echo_info "Centreon Plugins directory" "$CENTREON_PLUGINS"
echo_info "Centreon Plugins temporary directory" "$CENTPLUGINS_TMP"
echo_info "Nagios Plugins directory:" "$PLUGIN_DIR"

yes_no_default "Proceed to installation?"
if [ "$?" -ne 0 ] ; then
    echo_info "Exiting"
    exit 1
fi

## Disconnect user if upgrade
if [ "$upgrade" = "1" ]; then
    echo_info "Disconnect users from WebUI"
    php $INSTALL_DIR/clean_session.php "$CENTREON_ETC" >> "$LOG_FILE" 2>&1
    check_result $? "All users are disconnected"
fi

## Create a random APP_SECRET key
HEX_KEY=($(dd if=/dev/urandom bs=32 count=1 status=none | $PHP_BIN -r "echo bin2hex(fread(STDIN, 32))"));
echo -e "\n"
echo_info "Generated random key: $HEX_KEY"
log "INFO" "Generated a random key : $HEX_KEY"

## Step 1: Copy files to temporary directory
echo_title "Step 1: Copy files to temporary directory"

## Create temporary folder and copy all sources into it
copy_in_tmp_dir 2>>$LOG_FILE

## Step 2: Prepare files
echo_title "Step 2: Prepare files"

### Change macros for insertBaseConf.sql
log "INFO" "Change macros for insertBaseConf.sql"
${SED} -i -e 's|@INSTALL_DIR_CENTREON@|'"$INSTALL_DIR_CENTREON"'|g' \
    -e 's|@BIN_MAIL@|'"$BIN_MAIL"'|g' \
    -e 's|@CENTREON_ETC@|'"$CENTREON_ETC"'|g' \
    -e 's|@CENTREON_LOG@|'"$CENTREON_LOG"'|g' \
    -e 's|@CENTREON_VARLIB@|'"$CENTREON_VARLIB"'|g' \
    -e 's|@BIN_RRDTOOL@|'"$BIN_RRDTOOL"'|g' \
    $TMP_DIR/source/www/install/insertBaseConf.sql
check_result $? "Change macros for 'insertBaseConf.sql'"

${SED} -i -e 's|@CENTSTORAGE_RRD@|'"$CENTSTORAGE_RRD"'|g' \
	$TMP_DIR/source/www/install/createTablesCentstorage.sql
check_result $? "Change macros for 'createTablesCentstorage.sql'"

### Change macros for SQL update files
macros="@CENTREON_ETC@,@CENTREON_CACHEDIR@,@CENTPLUGINSTRAPS_BINDIR@,@CENTREON_LOG@,@CENTREON_VARLIB@,@CENTREON_ENGINE_CONNECTORS@"
find_macros_in_dir "$macros" "$TMP_DIR/source/" "www" "Update*.sql" "file_sql_temp"

flg_error=0
${CAT} "$file_sql_temp" | while read file ; do
    log "MACRO" "Change macro for : $file"
    ${SED} -i -e 's|@CENTREON_ETC@|'"$CENTREON_ETC"'|g' \
        -e 's|@CENTREON_CACHEDIR@|'"$CENTREON_CACHEDIR"'|g' \
        -e 's|@CENTPLUGINSTRAPS_BINDIR@|'"$CENTPLUGINSTRAPS_BINDIR"'|g' \
        -e 's|@CENTREON_VARLIB@|'"$CENTREON_VARLIB"'|g' \
        -e 's|@CENTREON_LOG@|'"$CENTREON_LOG"'|g' \
        -e 's|@CENTREON_ENGINE_CONNECTORS@|'"$CENTREON_ENGINE_CONNECTORS"'|g' \
        $TMP_DIR/source/$file
        [ $? -ne 0 ] && flg_error=1
    log "MACRO" "Copy in final dir : $file"
done
check_result $flg_error "Change macros for SQL update files"

### Change macros for PHP files
macros="@CENTREON_ETC@,@CENTREON_CACHEDIR@,@CENTPLUGINSTRAPS_BINDIR@,@CENTREON_LOG@,@CENTREON_VARLIB@,@CENTREONTRAPD_BINDIR@,@PHP_BIN@,%APP_SECRET%"
find_macros_in_dir "$macros" "$TMP_DIR/source/" "config" "*.php*" "file_php_config_temp"
find_macros_in_dir "$macros" "$TMP_DIR/source/" "." ".env*" "file_env_temp"
find_macros_in_dir "$macros" "$TMP_DIR/source/" "www" "*.php" "file_php_temp"
find_macros_in_dir "$macros" "$TMP_DIR/source/" "bin" "*" "file_bin_temp"
log "INFO" "Apply macros on PHP files"

flg_error=0
${CAT} "$file_php_config_temp" "$file_env_temp" "$file_php_temp" "$file_bin_temp" | while read file ; do
        log "MACRO" "Change macro for : $file"
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
        log "MACRO" "Copy in final dir : $file"
done
check_result $flg_error "Change macros for PHP files"

### Change macros for Perl files
macros="@CENTREON_ETC@,@CENTREON_CACHEDIR@,@CENTPLUGINSTRAPS_BINDIR@,@CENTREON_LOG@,@CENTREON_VARLIB@,@CENTREONTRAPD_BINDIR@"
find_macros_in_dir "$macros" "$TMP_DIR/source/" "bin/" "*" "file_perl_temp"

flg_error=0
${CAT} "$file_perl_temp" | while read file ; do
        log "MACRO" "Change macro for : $file"
        ${SED} -i -e 's|@CENTREON_ETC@|'"$CENTREON_ETC"'|g' \
                -e 's|@CENTREON_CACHEDIR@|'"$CENTREON_CACHEDIR"'|g' \
                -e 's|@CENTPLUGINSTRAPS_BINDIR@|'"$CENTPLUGINSTRAPS_BINDIR"'|g' \
                -e 's|@CENTREONTRAPD_BINDIR@|'"$CENTREON_BINDIR"'|g' \
                -e 's|@CENTREON_VARLIB@|'"$CENTREON_VARLIB"'|g' \
                -e 's|@CENTREON_LOG@|'"$CENTREON_LOG"'|g' \
                $TMP_DIR/source/$file
                [ $? -ne 0 ] && flg_error=1
        log "MACRO" "Copy in final dir : $file"
done
check_result $flg_error "Change macros for Perl files"

### Change macros for centAcl.php
log "INFO" "Change macros for centAcl.php"
${SED} -i -e 's|@CENTREON_ETC@|'"$CENTREON_ETC"'|g' \
    -e 's|@PHP_BIN@|'"$PHP_BIN"'|g' \
    $TMP_DIR/source/cron/centAcl.php
check_result $? "Change macros for 'centAcl.php'"

### Change macros for downtimeManager.php
log "INFO" "Change macros for downtimeManager.php"
${SED} -i -e 's|@CENTREON_ETC@|'"$CENTREON_ETC"'|g' \
    -e 's|@CENTREON_VARLIB@|'"$CENTREON_VARLIB"'|g' \
    -e 's|@PHP_BIN@|'"$PHP_BIN"'|g' \
    $TMP_DIR/source/cron/downtimeManager.php
check_result $? "Change macros for 'downtimeManager.php'"

### Change macros for centreon-backup.pl
log "INFO" "Change macros for centreon-backup.pl"
${SED} -i -e 's|@CENTREON_ETC@|'"$CENTREON_ETC"'|g' \
    -e 's|@PHP_BIN@|'"$PHP_BIN"'|g' \
    $TMP_DIR/source/cron/centreon-backup.pl
check_result $? "Change macros for 'centreon-backup.pl'"

### Change macros for Centreon cron
log "INFO" "Change macros for centreon.cron"
${SED} -i -e 's|@PHP_BIN@|'"$PHP_BIN"'|g' \
    -e 's|@PERL_BIN@|'"$BIN_PERL"'|g' \
    -e 's|@CENTREON_ETC@|'"$CENTREON_ETC"'|g' \
    -e 's|@INSTALL_DIR_CENTREON@|'"$INSTALL_DIR_CENTREON"'|g' \
    -e 's|@CENTREON_LOG@|'"$CENTREON_LOG"'|g' \
    -e 's|@CENTREON_USER@|'"$CENTREON_USER"'|g' \
    -e 's|@WEB_USER@|'"$WEB_USER"'|g' \
    $TMP_DIR/source/install/tmpl/centreon.cron
check_result $? "Change macros for cron/centreon file"

log "INFO" "Change macros for centstorage.cron"
${SED} -i -e 's|@PHP_BIN@|'"$PHP_BIN"'|g' \
	-e 's|@CENTSTORAGE_BINDIR@|'"$CENTSTORAGE_BINDIR"'|g' \
	-e 's|@INSTALL_DIR_CENTREON@|'"$INSTALL_DIR_CENTREON"'|g' \
	-e 's|@CENTREON_LOG@|'"$CENTREON_LOG"'|g' \
	-e 's|@CENTREON_ETC@|'"$CENTREON_ETC"'|g' \
	-e 's|@CENTREON_USER@|'"$CENTREON_USER"'|g' \
	-e 's|@WEB_USER@|'"$WEB_USER"'|g' \
    $TMP_DIR/source/install/tmpl/centstorage.cron
check_result $? "Change macros for cron/centstorage file"

### Change macros for Centreon logrotate
log "INFO" "Change macros for centreon.logrotate"
${SED} -i -e 's|@CENTREON_LOG@|'"$CENTREON_LOG"'|g' \
    $TMP_DIR/source/logrotate/centreon
check_result $? "Change macros for logrotate file"

## Step 3: Copy files to final directory
echo_title "Step 3: Copy files to final directory"

### Configuration directory
$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$CENTREON_USER" -g "$CENTREON_GROUP" \
    -d 775 \
    "$CENTREON_ETC" >> "$LOG_FILE" 2>&1
check_result $? "Install '$CENTREON_ETC/'"

$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$CENTREON_USER" -g "$CENTREON_GROUP" \
    -m 644 \
    $TMP_DIR/source/www/install/var/config.yaml \
    $CENTREON_ETC/config.yaml >> "$LOG_FILE" 2>&1
check_result $? "Install '$CENTREON_ETC/config.yaml'"

$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$CENTREON_USER" -g "$CENTREON_GROUP" \
    -d 775 \
    $CENTREON_ETC/config.d >> "$LOG_FILE" 2>&1
check_result $? "Install '$CENTREON_ETC/config.d/'"

### Log directory
$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$CENTREON_USER" -g "$CENTREON_GROUP" \
    -d 775 \
    "$CENTREON_LOG" >> "$LOG_FILE" 2>&1
check_result $? "Install '$CENTREON_LOG/'"

### Variable libraries directory
$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$CENTREON_USER" -g "$CENTREON_GROUP" \
    -d 775 \
    "$CENTREON_VARLIB/" >> "$LOG_FILE" 2>&1
check_result $? "Install '$CENTREON_VARLIB/'"

$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$CENTREON_USER" -g "$CENTREON_GROUP" \
    -d 775 \
    "$CENTREON_CENTCORE/" >> "$LOG_FILE" 2>&1
check_result $? "Install '$CENTREON_CENTCORE/'"

$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$CENTREON_USER" -g "$CENTREON_GROUP" \
    -d 775 \
    "$CENTREON_VARLIB/installs" >> "$LOG_FILE" 2>&1
check_result $? "Install '$CENTREON_VARLIB/installs/'"

### RRD directories
$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$CENTREON_USER" -g "$CENTREON_GROUP" \
    -d 775 \
    "$CENTSTORAGE_RRD/status/" >> "$LOG_FILE" 2>&1
check_result $? "Install '$CENTSTORAGE_RRD/status/'"

$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$CENTREON_USER" -g "$CENTREON_GROUP" \
    -d 775 \
    "$CENTSTORAGE_RRD/metrics/" >> "$LOG_FILE" 2>&1
check_result $? "Install '$CENTSTORAGE_RRD/metrics/'"

### Centreon Plugins temporary directory
$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$CENTREON_USER" -g "$CENTREON_GROUP" \
    -d 775 \
    "$CENTPLUGINS_TMP/" >> "$LOG_FILE" 2>&1
check_result $? "Install '$CENTPLUGINS_TMP/'"

### Run directory
$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$CENTREON_USER" -g "$CENTREON_GROUP" \
    -d 750 \
	"$CENTREON_RUNDIR" >> "$LOG_FILE" 2>&1
check_result $? "Install '$CENTREON_RUNDIR/'"

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
check_result $? "Install '$INSTALL_DIR_CENTREON/www/'"

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
check_result $? "Install '$INSTALL_DIR_CENTREON/src/'"

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
check_result $? "Install '$INSTALL_DIR_CENTREON/api/'"

### Cron binary
$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$CENTREON_USER" -g "$CENTREON_GROUP" \
    -d 755 -m 755 \
    $TMP_DIR/source/cron/* \
    $INSTALL_DIR_CENTREON/cron/ >> "$LOG_FILE" 2>&1
check_result $? "Install '$INSTALL_DIR_CENTREON/cron/'"

### Extra directories
[ ! -d "$INSTALL_DIR_CENTREON/www/modules" ] && \
    $INSTALL_DIR/cinstall $cinstall_opts \
        -u "$CENTREON_USER" -g "$CENTREON_GROUP" \
        -d 755 \
        $INSTALL_DIR_CENTREON/www/modules >> "$LOG_FILE" 2>&1 && \
        check_result $? "Install '$INSTALL_DIR_CENTREON/www/modules'"

[ ! -d "$INSTALL_DIR_CENTREON/www/img/media" ] && \
    $INSTALL_DIR/cinstall $cinstall_opts \
        -u "$CENTREON_USER" -g "$CENTREON_GROUP" \
        -d 775 \
        $INSTALL_DIR_CENTREON/www/img/media >> "$LOG_FILE" 2>&1 && \
        check_result $? "Install '$INSTALL_DIR_CENTREON/www/img/media'"

### Bases
$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$WEB_USER" -g "$WEB_GROUP" \
    -m 644 \
    $TMP_DIR/source/bootstrap.php $INSTALL_DIR_CENTREON/bootstrap.php >> "$LOG_FILE" 2>&1
check_result $? "Install '$INSTALL_DIR_CENTREON/bootstrap.php'"

$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$WEB_USER" -g "$WEB_GROUP" \
    -m 644 \
    $TMP_DIR/source/.env $INSTALL_DIR_CENTREON/.env >> "$LOG_FILE" 2>&1
check_result $? "Install '$INSTALL_DIR_CENTREON/.env'"

$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$WEB_USER" -g "$WEB_GROUP" \
    -m 644 \
    $TMP_DIR/source/.env.local.php $INSTALL_DIR_CENTREON/.env.local.php >> "$LOG_FILE" 2>&1
check_result $? "Install '$INSTALL_DIR_CENTREON/.env.local.php'"

$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$WEB_USER" -g "$WEB_GROUP" \
    -m 644 \
    $TMP_DIR/source/container.php $INSTALL_DIR_CENTREON/container.php >> "$LOG_FILE" 2>&1
check_result $? "Install '$INSTALL_DIR_CENTREON/container.php'"

### Composer
$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$WEB_USER" -g "$WEB_GROUP" \
    -m 644 \
    $TMP_DIR/source/composer.json $INSTALL_DIR_CENTREON/composer.json >> "$LOG_FILE" 2>&1
check_result $? "Install '$INSTALL_DIR_CENTREON/composer.json'"

### npms
$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$WEB_USER" -g "$WEB_GROUP" \
    -m 644 \
    $TMP_DIR/source/package.json $INSTALL_DIR_CENTREON/package.json >> "$LOG_FILE" 2>&1
check_result $? "Install '$INSTALL_DIR_CENTREON/package.json'"

$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$WEB_USER" -g "$WEB_GROUP" \
    -m 644 \
    $TMP_DIR/source/package-lock.json \
    $INSTALL_DIR_CENTREON/package-lock.json >> "$LOG_FILE" 2>&1
check_result $? "Install '$INSTALL_DIR_CENTREON/package-lock.json'"

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
check_result $? "Install '$INSTALL_DIR_CENTREON/vendor/'"

$INSTALL_DIR/cinstall $cinstall \
    -u "$CENTREON_USER" -g "$CENTREON_GROUP" \
    -d 775 \
    $INSTALL_DIR_CENTREON/config >> "$LOG_FILE" 2>&1

$INSTALL_DIR/cinstall $cinstall \
    -u "$WEB_USER" -g "$WEB_GROUP" \
    -d 755 -m 644 \
    $TMP_DIR/source/config/* \
    $INSTALL_DIR_CENTREON/config/ >> "$LOG_FILE" 2>&1
check_result $? "Install '$INSTALL_DIR_CENTREON/config/'"

### Smarty directories
$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$CENTREON_USER" -g "$CENTREON_GROUP" \
    -d 755 -m 664 \
    $TMP_DIR/source/GPL_LIB/* \
    $INSTALL_DIR_CENTREON/GPL_LIB/ >> "$LOG_FILE" 2>&1
check_result $? "Install '$INSTALL_DIR_CENTREON/GPL_LIB/'"

### Install Centreon binaries
$INSTALL_DIR/cinstall $cinstall_opts \
    -m 755 \
    $TMP_DIR/source/bin/* \
    $CENTREON_BINDIR/ >> "$LOG_FILE" 2>&1
check_result $? "Install '$CENTREON_BINDIR/'"

### Install libraries for Centreon CLAPI
$INSTALL_DIR/cinstall $cinstall \
    -u "$CENTREON_USER" -g "$CENTREON_GROUP" \
    -d 775 \
    $INSTALL_DIR_CENTREON/lib/Centreon >> "$LOG_FILE" 2>&1

$INSTALL_DIR/cinstall $cinstall_opts \
    -d 755 -m 664 \
    $TMP_DIR/source/lib/Centreon/* \
    $INSTALL_DIR_CENTREON/lib/Centreon/ >> "$LOG_FILE" 2>&1
check_result $? "Install '$INSTALL_DIR_CENTREON/lib/Centreon/'"

### Cache directories
$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$CENTREON_USER" -g "$CENTREON_GROUP" \
    -d 775 \
    $CENTREON_CACHEDIR/config >> "$LOG_FILE" 2>&1
check_result $? "Install '$CENTREON_CACHEDIR/config/'"

$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$CENTREON_USER" -g "$CENTREON_GROUP" \
    -d 775 \
    $CENTREON_CACHEDIR/config/engine >> "$LOG_FILE" 2>&1
check_result $? "Install '$CENTREON_CACHEDIR/config/engine/'"

$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$CENTREON_USER" -g "$CENTREON_GROUP" \
    -d 775 \
    $CENTREON_CACHEDIR/config/broker >> "$LOG_FILE" 2>&1
check_result $? "Install '$CENTREON_CACHEDIR/config/broker/'"

$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$CENTREON_USER" -g "$CENTREON_GROUP" \
    -d 775 \
    $CENTREON_CACHEDIR/config/export >> "$LOG_FILE" 2>&1
check_result $? "Install '$CENTREON_CACHEDIR/config/export/'"

$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$CENTREON_USER" -g "$CENTREON_GROUP" \
    -d 775 \
    $CENTREON_CACHEDIR/symfony >> "$LOG_FILE" 2>&1
check_result $? "Install '$CENTREON_CACHEDIR/symfony/'"

### Cron stuff
$INSTALL_DIR/cinstall $cinstall_opts \
    -m 644 \
    $TMP_DIR/source/install/tmpl/centreon.cron \
    $CRON_D/centreon >> "$LOG_FILE" 2>&1
check_result $? "Install '$CRON_D/centreon'"

$INSTALL_DIR/cinstall $cinstall_opts \
    -m 644 \
    $TMP_DIR/source/install/tmpl/centstorage.cron \
    $CRON_D/centstorage >> "$LOG_FILE" 2>&1
check_result $? "Install '$CRON_D/centstorage'"

### Logrotate
$INSTALL_DIR/cinstall $cinstall_opts \
    -m 644 \
    $TMP_DIR/source/logrotate/centreon \
    $LOGROTATE_D/centreon >> "$LOG_FILE" 2>&1
check_result $? "Install '$LOGROTATE_D/centreon'"

### Install Centreon Perl lib
$INSTALL_DIR/cinstall $cinstall_opts \
    -d 755 -m 644 \
    $TMP_DIR/source/lib/perl/centreon/* \
    $PERL_LIB_DIR/centreon/ >> $LOG_FILE 2>&1
check_result $? "Install '$PERL_LIB_DIR/centreon/'"

## Step 4: Configure Engine, Broker and Gorgone
echo_title "Step 4: Configure Engine, Broker and Gorgone"

### Copy Pollers SSH keys (in case of upgrade) to the new "user" gorgone
if [ "$upgrade" = "1" ]; then
    copy_ssh_keys_to_gorgone
fi

### Create Gorgone Centreon specific configuration
${SED} -i -e 's|@CENTREON_ETC@|'"$CENTREON_ETC"'|g' \
    $TMP_DIR/source/www/install/var/gorgone/gorgoneRootConfigTemplate.yaml
check_result $? "Change macros for '30-centreon.yaml'"

$INSTALL_DIR/cinstall $cinstall_opts \
    -u "$GORGONE_USER" -g "$GORGONE_GROUP" \
    -m 644 \
    $TMP_DIR/source/www/install/var/gorgone/gorgoneRootConfigTemplate.yaml \
    $GORGONE_CONFIG/config.d/30-centreon.yaml >> "$LOG_FILE" 2>&1
check_result $? "Install '$GORGONE_CONFIG/config.d/30-centreon.yaml'"

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
check_result $flg_error "Modify rights on '$ENGINE_ETC'"

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
    check_result $flg_error "Modify rights on '$BROKER_ETC'"
fi

## Step 5: Update groups memberships
echo_title "Step 5: Update groups memberships"
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
echo_title "Step 6: Configure Sudo"
configure_sudo "$TMP_DIR/examples"

## Step 7: Configure Apache
echo_title "Step 7: Configure Apache"
configure_apache "$TMP_DIR/examples"

## Step 8: Configure PHP FPM
echo_title "Step 8: Configure PHP FPM"
configure_php_fpm "$TMP_DIR/examples"

# End
echo_title "Create configuration and installation files"

## Create configfile for web install
createConfFile

## Write install config file
createCentreonInstallConf
createCentPluginsInstallConf

## Purge working directories
purge_centreon_tmp_dir "silent"
server=`hostname -I | cut -d" " -f1`

# End
echo_title "You're done!"
echo_info "You can now connect to the following URL to finalize installation:"
echo_info "\thttp://$server/centreon/"
echo_info ""
echo_info "Take a look at the documentation"
echo_info "https://docs.centreon.com/current/en/installation/web-and-post-installation.html."
echo_info "Thanks for using Centreon!"
echo_info "Follow us on https://github.com/centreon/centreon!"

exit 0
