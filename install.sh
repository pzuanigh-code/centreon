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

## load all functions used in this script
. $INSTALL_DIR/inputvars.default
. $INSTALL_DIR/functions

# Checking installation script requirements
BINARIES="rm cp mv ${CHMOD} ${CHOWN} echo more mkdir find ${GREP} ${CAT} ${SED}"
binary_fail="0"
# For the moment, I check if all binary exists in path.
# After, I must look a solution to use complet path by binary
for binary in $BINARIES; do
	if [ ! -e ${binary} ] ; then 
		pathfind_ret "$binary" "PATH_BIN"
		if [ "$?" -ne 0 ] ; then
			echo_failure "${binary}" "$fail"
			binary_fail=1
		fi
	fi
done

# Script stop if one binary is not found
if [ "$binary_fail" -eq 1 ] ; then
	echo_info "Please check failed binary and retry"
	exit 1
else
	echo_success "Script requirements" "$ok"
fi

## Load specific variables
find_os DISTRIB
echo_info "Found distribution" "$DISTRIB"

if [ -f $INSTALL_DIR/inputvars.$DISTRIB ]; then
    echo_info "Loading distribution specific input variables" "$INSTALL_DIR/inputvars.$DISTRIB"
    . $INSTALL_DIR/inputvars.$DISTRIB
fi

if [ -f $INSTALL_DIR/inputvars ]; then
    echo_info "Loading user specific input variables" "$INSTALL_DIR/inputvars"
    . $INSTALL_DIR/inputvars
fi

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
			upgrade="1" 
			_tmp_install_opts="1"
			;;
		\?|h)	usage ; exit 0 ;;
		* )	usage ; exit 1 ;;
	esac
done

if [ "$_tmp_install_opts" -eq 0 ] ; then
	usage
	exit 1
fi

# Export variable for all programs
export silent_install user_install_vars inst_upgrade_dir upgrade

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
if [ "$?" -ne 0 ] ; then
    echo_info "Exiting"
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
fi

# Start installation

## Check space of tmp dir
check_tmp_disk_space
if [ "$?" -eq 1 ] ; then
    if [ "$silent_install" -eq 1 ] ; then
        purge_centreon_tmp_dir "silent"
    else
        purge_centreon_tmp_dir
    fi
fi

requirements_failed=""
export requirements_failed

# Checking requirements
echo_title "Checking Centreon installation requirements"
test_dir "$BASE_DIR/vendor" "Composer dependencies"
if [ "$?" -ne 0 ] ; then requirements_failed="0" ; fi
test_dir "$BASE_DIR/www/static" "Frontend application"
if [ "$?" -ne 0 ] ; then requirements_failed="0" ; fi
test_file_from_var "PERL_BINARY" "Perl binary"
test_file_from_var "RRDTOOL_BINARY" "RRDTool binary"
test_file_from_var "MAIL_BINARY" "Mail binary"
test_dir_from_var "CROND_ETC_DIR" "Cron directory"
test_dir_from_var "LOGROTATED_ETC_DIR" "Logrotate directory"
test_dir_from_var "SUDOERSD_ETC_DIR" "Sudoers directory"
test_dir_from_var "SNMP_ETC_DIR" "SNMP configuration directory"
test_dir_from_var "NAGIOS_PLUGINS_DIR" "Nagios Plugins directory"

## Apache information
check_apache_user
check_apache_group
check_apache_directory
test_user_from_var "APACHE_USER" "Apache user"
test_group_from_var "APACHE_GROUP" "Apache group"
# test_file_from_var "APACHE_CONF" "Apache configuration"
test_dir_from_var "APACHE_DIR" "Apache directory"
test_dir_from_var "APACHE_CONF_DIR" "Apache configuration directory"

## MariaDB information
check_mariadb_directory
test_dir "$MARIADB_CONF_DIR" "MariaDB configuration directory"
install_mariadb_conf="1"
if [ "$?" -ne 0 ] ; then
    echo_info "Add the following configuration on your database server:"
    print_mariadb_conf
    install_mariadb_conf="0"
fi

## PHP information
get_timezone
check_php_fpm_directory
test_value_from_var "PHP_TIMEZONE" "PHP timezone"
test_dir_from_var "PHPFPM_LOG_DIR" "PHP FPM log directory"
test_dir_from_var "PHPFPM_CONF_DIR" "PHP FPM configuration directory"
test_dir_from_var "PHPFPM_SERVICE_DIR" "PHP FPM service directory"
test_dir_from_var "PHP_ETC_DIR" "PHP configuration directory"
test_file_from_var "PHP_BINARY" "PHP binary"
check_php_version
if [ "$?" -ne 0 ] ; then requirements_failed="${requirements_failed}PHP_MIN_VERSION " ; fi

## Perl information
check_perl_lib_directory
test_dir_from_var "PERL_LIB_DIR" "Perl libraries directory"

## Engine information
test_user_from_var "ENGINE_USER" "Engine user"
test_group_from_var "ENGINE_GROUP" "Engine group"
test_file_from_var "ENGINE_BINARY" "Engine binary"
test_dir_from_var "ENGINE_ETC_DIR" "Engine configuration directory"
test_dir_from_var "ENGINE_LOG_DIR" "Engine log directory" 
test_dir_from_var "ENGINE_LIB_DIR" "Engine library directory"
test_dir_from_var "ENGINE_CONNECTORS_DIR" "Engine Connectors directory"

## Broker information
test_user_from_var "BROKER_USER" "Broker user"
test_group_from_var "BROKER_GROUP" "Broker group"
test_dir_from_var "BROKER_ETC_DIR" "Broker configuration directory"
test_dir_from_var "BROKER_VARLIB_DIR" "Broker variable library directory"
test_dir_from_var "BROKER_LOG_DIR" "Broker log directory"
test_file_from_var "BROKER_MOD_BINARY" "Broker module binary"

## Gorgone information
test_user_from_var "GORGONE_USER" "Gorgone user"
test_group_from_var "GORGONE_GROUP" "Gorgone group"
test_dir_from_var "GORGONE_ETC_DIR" "Gorgone configuration directory"
test_dir_from_var "GORGONE_VARLIB_DIR" "Gorgone variable library directory"

## Plugins information
test_dir_from_var "CENTREON_PLUGINS_DIR" "Centreon Plugins directory"
test_dir_from_var "NAGIOS_PLUGINS_DIR" "Nagios Plugins directory"

echo_success "Installation requirements" "$ok"

## Centreon information summary
echo_title "Centreon information"
echo_info "Centreon installation directory" "$CENTREON_INSTALL_DIR"
echo_info "Centreon configuration directory" "$CENTREON_ETC_DIR"
echo_info "Centreon log directory" "$CENTREON_LOG_DIR"
echo_info "Centreon variable library directory" "$CENTREON_VARLIB_DIR"
echo_info "Centreon Centcore directory" "$CENTREON_CENTCORE_DIR"
echo_info "Centreon RRD status directory" "$CENTREON_RRD_STATUS_DIR"
echo_info "Centreon RRD metrics directory" "$CENTREON_RRD_METRICS_DIR"
echo_info "Centreon Plugins temporary directory" "$CENTREON_PLUGINS_TMP_DIR"
echo_info "Centreon cache directory" "$CENTREON_CACHE_DIR"
echo_info "Centreon run directory" "$CENTREON_RUN_DIR"
echo_info "Centreon user" "$CENTREON_USER"
echo_info "Centreon group" "$CENTREON_GROUP"

if [ ! -z "$requirements_failed" ] ; then
    echo_info "\n\tPlease define the following variables:"
    echo_info "\n\t$requirements_failed"
    echo_info "\n"
    purge_centreon_tmp_dir "silent"
    exit 1
fi

# Start installation
yes_no_default "Everything looks good, proceed to installation?"
if [ "$?" -ne 0 ] ; then
    purge_centreon_tmp_dir "silent"
    exit 1
fi

## Ask for HTTP/HTTPS
if [ -z $USE_HTTPS ] ; then
    yes_no_default "Deploy HTTPS configuration for Apache?"
    if [ "$?" -eq 0 ] ; then
        USE_HTTPS=1
    else
        USE_HTTPS=0
    fi
fi

## Disconnect user if upgrade
if [ "$upgrade" = "1" ]; then
    echo_info "Disconnect users from WebUI"
    php $INSTALL_DIR/clean_session.php "$CENTREON_ETC" >> "$LOG_FILE" 2>&1
    check_result $? "All users are disconnected"
fi

## Create a random APP_SECRET key
HEX_KEY=($(dd if=/dev/urandom bs=32 count=1 status=none | $PHP_BINARY -r "echo bin2hex(fread(STDIN, 32));"));
echo -e "\n"
echo_info "Generated random key: $HEX_KEY"

## Build files
echo_title "Build files"
echo_info "Copying files to '$TMP_DIR'"
copy_in_tmp_dir 2>>$LOG_FILE
if [ "$?" -ne 0 ] ; then
    echo_failure "Error when copying files to '$TMP_DIR'" "$fail"
    purge_centreon_tmp_dir "silent"
    exit 1
fi

echo_info "Replacing macros"
replace_macro
if [ "$?" -ne 0 ] ; then
    echo_failure "Error replacing macros" "$fail"
    purge_centreon_tmp_dir "silent"
    exit 1
fi

echo_info "Building installation tree"
BUILD_DIR="$TMP_DIR/build"
create_dir "$BUILD_DIR"

# Create user and group
create_group "$CENTREON_GROUP"
create_user "$CENTREON_USER" "$CENTREON_GROUP" "$CENTREON_HOME"

# Centreon configuration
create_dir "$BUILD_DIR/$CENTREON_ETC_DIR"
create_dir "$BUILD_DIR/$CENTREON_ETC_DIR/config.d"
copy_file "$TMP_DIR/source/www/install/var/config.yaml" "$BUILD_DIR/$CENTREON_ETC_DIR/config.yaml"
copy_file "$TMP_DIR/source/install/src/instCentWeb.conf" "$BUILD_DIR/$CENTREON_ETC_DIR/instCentWeb.conf"
set_ownership "$BUILD_DIR/$CENTREON_ETC_DIR" "$CENTREON_USER" "$CENTREON_GROUP"
set_permissions "$BUILD_DIR/$CENTREON_ETC_DIR" "775"
set_permissions "$BUILD_DIR/$CENTREON_ETC_DIR/*" "644"

### Log directory
create_dir "$BUILD_DIR/$CENTREON_LOG_DIR"
set_ownership "$BUILD_DIR/$CENTREON_LOG_DIR" "$CENTREON_USER" "$CENTREON_GROUP"
set_permissions "$BUILD_DIR/$CENTREON_LOG_DIR" "775"

### Variable libraries directory
create_dir "$BUILD_DIR/$CENTREON_VARLIB_DIR"
set_ownership "$BUILD_DIR/$CENTREON_VARLIB_DIR" "$CENTREON_USER" "$CENTREON_GROUP"
set_permissions "$BUILD_DIR/$CENTREON_VARLIB_DIR" "775"

create_dir "$BUILD_DIR/$CENTREON_VARLIB_DIR/installs"
set_ownership "$BUILD_DIR/$CENTREON_VARLIB_DIR/installs" "$CENTREON_USER" "$CENTREON_GROUP"
set_permissions "$BUILD_DIR/$CENTREON_VARLIB_DIR/installs" "775"

create_dir "$BUILD_DIR/$CENTREON_CENTCORE_DIR"
set_ownership "$BUILD_DIR/$CENTREON_CENTCORE_DIR" "$CENTREON_USER" "$CENTREON_GROUP"
set_permissions "$BUILD_DIR/$CENTREON_CENTCORE_DIR" "775"

### RRD directories
create_dir "$BUILD_DIR/$CENTREON_RRD_STATUS_DIR"
set_ownership "$BUILD_DIR/$CENTREON_RRD_STATUS_DIR" "$CENTREON_USER" "$CENTREON_GROUP"
set_permissions "$BUILD_DIR/$CENTREON_RRD_STATUS_DIR" "775"

create_dir "$BUILD_DIR/$CENTREON_RRD_METRICS_DIR"
set_ownership "$BUILD_DIR/$CENTREON_RRD_METRICS_DIR" "$CENTREON_USER" "$CENTREON_GROUP"
set_permissions "$BUILD_DIR/$CENTREON_RRD_METRICS_DIR" "775"

### Centreon Plugins temporary directory
create_dir "$BUILD_DIR/$CENTREON_PLUGINS_TMP_DIR"
set_ownership "$BUILD_DIR/$CENTREON_PLUGINS_TMP_DIR" "$CENTREON_USER" "$CENTREON_GROUP"
set_permissions "$BUILD_DIR/$CENTREON_PLUGINS_TMP_DIR" "775"

### Run directory
create_dir "$BUILD_DIR/$CENTREON_RUN_DIR"
set_ownership "$BUILD_DIR/$CENTREON_RUN_DIR" "$CENTREON_USER" "$CENTREON_GROUP"
set_permissions "$BUILD_DIR/$CENTREON_RUN_DIR" "750"

### Cache directories
create_dir "$BUILD_DIR/$CENTREON_CACHE_DIR/backup"
create_dir "$BUILD_DIR/$CENTREON_CACHE_DIR/config/engine"
create_dir "$BUILD_DIR/$CENTREON_CACHE_DIR/config/broker"
create_dir "$BUILD_DIR/$CENTREON_CACHE_DIR/config/export"
set_ownership "$BUILD_DIR/$CENTREON_CACHE_DIR" "$CENTREON_USER" "$CENTREON_GROUP"
set_permissions "$BUILD_DIR/$CENTREON_CACHE_DIR" "775"
create_dir "$BUILD_DIR/$CENTREON_CACHE_DIR/symfony"
set_ownership "$BUILD_DIR/$CENTREON_CACHE_DIR/symfony" "$APACHE_USER" "$APACHE_GROUP"
set_permissions "$BUILD_DIR/$CENTREON_CACHE_DIR/symfony" "755"

### Install directory
create_dir "$BUILD_DIR/$CENTREON_INSTALL_DIR"
set_ownership "$BUILD_DIR/$CENTREON_INSTALL_DIR" "$CENTREON_USER" "$CENTREON_GROUP"
set_permissions "$BUILD_DIR/$CENTREON_INSTALL_DIR" "775"

### Web directory
copy_dir "$TMP_DIR/source/www" "$BUILD_DIR/$CENTREON_INSTALL_DIR/www"
copy_file "$TMP_DIR/source/install/install.conf.php" "$BUILD_DIR/$CENTREON_INSTALL_DIR/www/install.conf.php"
set_ownership "$BUILD_DIR/$CENTREON_INSTALL_DIR/www" "$CENTREON_USER" "$CENTREON_GROUP"
set_permissions "$BUILD_DIR/$CENTREON_INSTALL_DIR/www" "775"
set_permissions "$BUILD_DIR/$CENTREON_INSTALL_DIR/www/*" "775"

### Sources
copy_dir "$TMP_DIR/source/src" "$BUILD_DIR/$CENTREON_INSTALL_DIR/src"
set_ownership "$BUILD_DIR/$CENTREON_INSTALL_DIR/src" "$CENTREON_USER" "$CENTREON_GROUP"
set_permissions "$BUILD_DIR/$CENTREON_INSTALL_DIR/src" "775"
set_permissions "$BUILD_DIR/$CENTREON_INSTALL_DIR/src/*" "775"

### API files
copy_dir "$TMP_DIR/source/api" "$BUILD_DIR/$CENTREON_INSTALL_DIR/api"
set_ownership "$BUILD_DIR/$CENTREON_INSTALL_DIR/api" "$CENTREON_USER" "$CENTREON_GROUP"
set_permissions "$BUILD_DIR/$CENTREON_INSTALL_DIR/api" "775"
set_permissions "$BUILD_DIR/$CENTREON_INSTALL_DIR/api/*" "775"

### Symfony config directories
copy_dir "$TMP_DIR/source/vendor" "$BUILD_DIR/$CENTREON_INSTALL_DIR/vendor"
set_permissions "$BUILD_DIR/$CENTREON_INSTALL_DIR/vendor" "755"
set_permissions "$BUILD_DIR/$CENTREON_INSTALL_DIR/vendor/*" "644"

copy_dir "$TMP_DIR/source/config" "$BUILD_DIR/$CENTREON_INSTALL_DIR/config"
set_permissions "$BUILD_DIR/$CENTREON_INSTALL_DIR/config" "755"
set_permissions "$BUILD_DIR/$CENTREON_INSTALL_DIR/config/*" "644"

copy_file "$BUILD_DIR/$CENTREON_INSTALL_DIR/config/centreon.config.php.template" \
    "$BUILD_DIR/$CENTREON_INSTALL_DIR/config/centreon.config.php"

### Smarty directories
copy_dir "$TMP_DIR/source/GPL_LIB" "$BUILD_DIR/$CENTREON_INSTALL_DIR/GPL_LIB"
set_ownership "$BUILD_DIR/$CENTREON_INSTALL_DIR/GPL_LIB" "$CENTREON_USER" "$CENTREON_GROUP"
set_permissions "$BUILD_DIR/$CENTREON_INSTALL_DIR/GPL_LIB" "775"
set_permissions "$BUILD_DIR/$CENTREON_INSTALL_DIR/GPL_LIB/*" "644"

### Centreon binaries
copy_dir "$TMP_DIR/source/bin" "$BUILD_DIR/$CENTREON_INSTALL_DIR/bin"
set_ownership "$BUILD_DIR/$CENTREON_INSTALL_DIR/bin" "$CENTREON_USER" "$CENTREON_GROUP"
set_permissions "$BUILD_DIR/$CENTREON_INSTALL_DIR/bin" "755"
set_permissions "$BUILD_DIR/$CENTREON_INSTALL_DIR/bin/*" "755"

### Centreon CLAPI
create_dir "$BUILD_DIR/$CENTREON_INSTALL_DIR/lib"
copy_dir "$TMP_DIR/source/lib/Centreon" "$BUILD_DIR/$CENTREON_INSTALL_DIR/lib/Centreon"
set_ownership "$BUILD_DIR/$CENTREON_INSTALL_DIR/lib" "$CENTREON_USER" "$CENTREON_GROUP"
set_permissions "$BUILD_DIR/$CENTREON_INSTALL_DIR/lib" "755"
set_permissions "$BUILD_DIR/$CENTREON_INSTALL_DIR/lib/Centreon/*" "644"

### Cron binary
create_dir "$BUILD_DIR/$CENTREON_INSTALL_DIR/cron"
set_ownership "$BUILD_DIR/$CENTREON_INSTALL_DIR/cron" "$CENTREON_USER" "$CENTREON_GROUP"
set_permissions "$BUILD_DIR/$CENTREON_INSTALL_DIR/cron" "775"

copy_file "$TMP_DIR/source/cron/*" "$BUILD_DIR/$CENTREON_INSTALL_DIR/cron"
set_ownership "$BUILD_DIR/$CENTREON_INSTALL_DIR/cron" "$CENTREON_USER" "$CENTREON_GROUP"
set_permissions "$BUILD_DIR/$CENTREON_INSTALL_DIR/cron/*" "755"

### Bases
copy_file "$TMP_DIR/source/bootstrap.php" "$BUILD_DIR/$CENTREON_INSTALL_DIR"
set_ownership "$BUILD_DIR/$CENTREON_INSTALL_DIR/bootstrap.php" "$APACHE_USER" "$APACHE_GROUP"
set_permissions "$BUILD_DIR/$CENTREON_INSTALL_DIR/bootstrap.php" "644"

copy_file "$TMP_DIR/source/container.php" "$BUILD_DIR/$CENTREON_INSTALL_DIR"
set_ownership "$BUILD_DIR/$CENTREON_INSTALL_DIR/container.php" "$APACHE_USER" "$APACHE_GROUP"
set_permissions "$BUILD_DIR/$CENTREON_INSTALL_DIR/container.php" "644"

copy_file "$TMP_DIR/source/composer.json" "$BUILD_DIR/$CENTREON_INSTALL_DIR"
set_ownership "$BUILD_DIR/$CENTREON_INSTALL_DIR/composer.json" "$APACHE_USER" "$APACHE_GROUP"
set_permissions "$BUILD_DIR/$CENTREON_INSTALL_DIR/composer.json" "644"

copy_file "$TMP_DIR/source/package.json" "$BUILD_DIR/$CENTREON_INSTALL_DIR"
set_ownership "$BUILD_DIR/$CENTREON_INSTALL_DIR/package.json" "$APACHE_USER" "$APACHE_GROUP"
set_permissions "$BUILD_DIR/$CENTREON_INSTALL_DIR/package.json" "644"

copy_file "$TMP_DIR/source/package-lock.json" "$BUILD_DIR/$CENTREON_INSTALL_DIR"
set_ownership "$BUILD_DIR/$CENTREON_INSTALL_DIR/package-lock.json" "$APACHE_USER" "$APACHE_GROUP"
set_permissions "$BUILD_DIR/$CENTREON_INSTALL_DIR/package-lock.json" "644"

### Cron stuff
create_dir "$BUILD_DIR/$CROND_ETC_DIR"
copy_file "$TMP_DIR/source/tmpl/install/centreon.cron" "$BUILD_DIR/$CROND_ETC_DIR/centreon"
set_permissions "$BUILD_DIR/$CROND_ETC_DIR/centreon" "644"
copy_file "$TMP_DIR/source/tmpl/install/centstorage.cron" "$BUILD_DIR/$CROND_ETC_DIR/centstorage"
set_permissions "$BUILD_DIR/$CROND_ETC_DIR/centstorage" "644"

### Install Centreon Perl lib
create_dir "$BUILD_DIR/$PERL_LIB_DIR/lib/perl"
copy_dir "$TMP_DIR/source/lib/perl/centreon" "$BUILD_DIR/$PERL_LIB_DIR/lib/perl/centreon"
set_permissions "$BUILD_DIR/$PERL_LIB_DIR/lib/perl/centreon" "755"
set_permissions "$BUILD_DIR/$PERL_LIB_DIR/lib/perl/centreon/*" "644"

### Gorgone configuration file
create_dir "$BUILD_DIR/$GORGONE_ETC_DIR/config.d"
copy_file "$TMP_DIR/source/www/install/var/gorgone/gorgoneRootConfigTemplate.yaml" \
    "$BUILD_DIR/$GORGONE_ETC_DIR/config.d/30-centreon.yaml"
set_ownership "$BUILD_DIR/$GORGONE_ETC_DIR" "$GORGONE_USER" "$GORGONE_GROUP"
set_permissions "$BUILD_DIR/$GORGONE_ETC_DIR" "755"
set_permissions "$BUILD_DIR/$GORGONE_ETC_DIR/config.d/30-centreon.yaml" "644"

### Sudoers configuration
create_dir "$BUILD_DIR/$SUDOERSD_ETC_DIR"
copy_file "$TMP_DIR/source/tmpl/install/sudoersCentreonEngine" "$BUILD_DIR/$SUDOERSD_ETC_DIR/centreon"

## Copy files to final directory
echo_title "Copy files to final directory"
echo_info "Copying files from '$TMP_DIR' to final directory"
copy_dir "$BUILD_DIR/*" "/"
if [ "$?" -ne 0 ] ; then
    echo_failure "Error copying files" "$fail"
    purge_centreon_tmp_dir "silent"
    exit 1
fi
exit 0

## Update groups memberships
echo_title "Update groups memberships"
add_user_to_group "$APACHE_USER" "$CENTREON_GROUP"
add_user_to_group "$ENGINE_USER" "$CENTREON_GROUP"
add_user_to_group "$APACHE_USER" "$ENGINE_GROUP"
add_user_to_group "$CENTREON_USER" "$ENGINE_GROUP"
add_user_to_group "$CENTREON_USER" "$APACHE_GROUP"
add_user_to_group "$APACHE_USER" "$BROKER_GROUP"
add_user_to_group "$ENGINE_USER" "$BROKER_GROUP"
add_user_to_group "$BROKER_USER" "$CENTREON_GROUP"
add_user_to_group "$CENTREON_USER" "$GORGONE_GROUP"
add_user_to_group "$APACHE_USER" "$GORGONE_GROUP"
add_user_to_group "$GORGONE_USER" "$CENTREON_GROUP"
add_user_to_group "$GORGONE_USER" "$BROKER_GROUP"
add_user_to_group "$GORGONE_USER" "$ENGINE_GROUP"
add_user_to_group "$GORGONE_USER" "$APACHE_GROUP"

### Copy Pollers SSH keys (in case of upgrade) to the new "user" gorgone
if [ "$upgrade" = "1" ]; then
    copy_ssh_keys_to_gorgone
fi

## Configure services
echo_title "Configure services"

### Centreon
enable_centreon="0"
copy_file_no_replace "$TMP_DIR/source/install/src/centreon.systemd" "$SYSTEMD_ETC_DIR/centreon.service"
retval=$?
if [ "$retval" == 0 ] ; then
    echo_success "Centreon service configuration" "$ok"
    enable_centreon="1"
elif [ "$retval" == 2 ] ; then
    echo_passed "Centreon service configuration" "$SYSTEMD_ETC_DIR/centreon.service.new"
fi

### Symfony
copy_file_no_replace "$TMP_DIR/source/.env" "$CENTREON_INSTALL_DIR"
retval=$?
if [ "$retval" == 0 ] ; then
    echo_success "Symfony .env" "$ok"
elif [ "$retval" == 2 ] ; then
    echo_passed "Symfony .env" "$CENTREON_INSTALL_DIR/.env.new"
fi
copy_file_no_replace "$TMP_DIR/source/.env.local.php" "$CENTREON_INSTALL_DIR"
retval=$?
if [ "$retval" == 0 ] ; then
    echo_success "Symfony .env.local.php" "$ok"
elif [ "$retval" == 2 ] ; then
    echo_passed "Symfony .env.local.php" "$CENTREON_INSTALL_DIR/.env.local.php.new"
fi

### Logrotate
copy_file_no_replace "$TMP_DIR/source/logrotate/centreon" "$LOGROTATED_ETC_DIR/centreon"
retval=$?
if [ "$retval" == 0 ] ; then
    echo_success "Logrotate Centreon configuration" "$ok"
elif [ "$retval" == 2 ] ; then
    echo_passed "Logrotate Centreon configuration" "$LOGROTATED_ETC_DIR/centreon.new"
fi
copy_file_no_replace "$TMP_DIR/source/logrotate/centreontrapd" "$LOGROTATED_ETC_DIR/centreontrapd"
retval=$?
if [ "$retval" == 0 ] ; then
    echo_success "Logrotate Centreontrapd configuration" "$ok"
elif [ "$retval" == 2 ] ; then
    echo_passed "Logrotate Centreontrapd configuration" "$LOGROTATED_ETC_DIR/centreontrapd.new"
fi

### Apache
reload_apache="0"
if [ $USE_HTTPS -eq 1 ] ; then
    copy_file_no_replace "$TMP_DIR/source/install/src/centreon-apache-https.conf" "$APACHE_CONF_DIR/10-centreon.conf"
    retval=$?
else
    copy_file_no_replace "$TMP_DIR/source/install/src/centreon-apache.conf" "$APACHE_CONF_DIR/10-centreon.conf"
    retval=$?
fi
if [ "$retval" == 0 ] ; then
    echo_success "Apache configuration" "$ok"
    reload_apache="1"
elif [ "$retval" == 2 ] ; then
    echo_passed "Apache configuration" "$APACHE_CONF_DIR/centreon.conf.new"
fi

### PHP FPM
restart_php_fpm="0"
copy_file_no_replace "$TMP_DIR/source/install/src/php-fpm.conf" "$PHPFPM_CONF_DIR/centreon.conf"
retval=$?
if [ "$retval" == 0 ] ; then
    echo_success "PHP FPM configuration" "$ok"
    restart_php_fpm="1"
elif [ "$retval" == 2 ] ; then
    echo_passed "PHP FPM configuration" "$PHPFPM_CONF_DIR/centreon.conf.new"
fi
copy_file_no_replace "$TMP_DIR/source/install/src/php-fpm-systemd.conf" "$PHPFPM_SERVICE_DIR/centreon.conf"
retval=$?
if [ "$retval" == 0 ] ; then
    echo_success "PHP FPM service configuration" "$ok"
    restart_php_fpm="1"
elif [ "$retval" == 2 ] ; then
    echo_passed "PHP FPM service configuration" "$PHPFPM_SERVICE_DIR/centreon.conf.new"
fi
copy_file_no_replace "$TMP_DIR/source/install/src/php.ini" "$PHP_ETC_DIR/50-centreon.ini"
retval=$?
if [ "$retval" == 0 ] ; then
    echo_success "PHP configuration" "$ok"
    restart_php_fpm="1"
elif [ "$retval" == 2 ] ; then
    echo_passed "PHP configuration" "$PHP_ETC_DIR/50-centreon.ini.new"
fi

### MariaDB
restart_mariadb="0"
if [ $install_mariadb_conf -eq 1 ] ; then
    copy_file_no_replace "$TMP_DIR/source/install/src/centreon-mysql.cnf" "$MARIADB_CONF_DIR/centreon.cnf"
    retval=$?
    if [ "$retval" == 0 ] ; then
        echo_success "MariaDB configuration" "$ok"
        restart_mariadb="1"
    elif [ "$retval" == 2 ] ; then
        echo_passed "MariaDB configuration" "$MARIADB_CONF_DIR/centreon.cnf.new"
    fi
    copy_file_no_replace "$TMP_DIR/source/install/src/mariadb-systemd.conf" "$MARIADB_SERVICE_DIR/centreon.conf"
    retval=$?
    if [ "$retval" == 0 ] ; then
        echo_success "MariaDB service configuration" "$ok"
        restart_mariadb="1"
    elif [ "$retval" == 2 ] ; then
        echo_passed "MariaDB service configuration" "$MARIADB_SERVICE_DIR/centreon.conf.new"
    fi
fi
if [ "$enable_centreon" -eq 1 ] || [ "$reload_apache" -eq 1 ] ||
    [ "$restart_php_fpm" -eq 1 ] || [ "$restart_mariadb" -eq 1 ] ; then
    reload_daemon
fi

if [ "$enable_centreon" -eq 1 ] ; then
    enable_service_centreon
fi
if [ "$reload_apache" -eq 1 ] ; then
    enable_conf_apache
    reload_service_apache
fi
if [ "$restart_php_fpm" -eq 1 ] ; then
    restart_service_php_fpm
fi
if [ "$restart_mariadb" -eq 1 ] ; then
    restart_service_mariadb
fi

# End

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
