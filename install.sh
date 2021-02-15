#!/bin/bash
#----
## @Synopsis	Install Script for Centreon project
## @Copyright	Copyright 2008, Guillaume Watteeux
## @Copyright	Copyright 2008-2021, Centreon
## @License	GPL : http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt
## Centreon Install Script
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
	echo -e "  -i\tinstall Centreon with interactive interface"
	echo -e "  -s\tinstall Centreon silently"
	echo -e "  -u\tupgrade Centreon specifying the directory of instCentWeb.conf file"
	echo -e "  -e\tenvironment variables, 'VAR=value' format (overides input files)"
	exit 1
}

## Define where are Centreon sources
BASE_DIR=$(dirname $0)
BASE_DIR=$( cd $BASE_DIR; pwd )
export BASE_DIR
if [ -z "${BASE_DIR#/}" ] ; then
	echo -e "You cannot select the filesystem root folder"
	exit 1
fi
INSTALL_DIR="$BASE_DIR/install"
export INSTALL_DIR

_tmp_install_opts="0"
silent_install="0"
upgrade="0"

## Get options
while getopts "isu:e:h" Options
do
	case ${Options} in
		i )	silent_install="0"
			_tmp_install_opts="1"
			;;
		s )	silent_install="1"
			_tmp_install_opts="1"
			;;
		u )	silent_install="1"
			UPGRADE_FILE="${OPTARG%/}"
			upgrade="1" 
			_tmp_install_opts="1"
			;;
        e) env_opts+=("$OPTARG")
			;;
		\?|h)	usage ; exit 0 ;;
		* )	usage ; exit 1 ;;
	esac
done
shift $((OPTIND -1))

if [ "$_tmp_install_opts" -eq 0 ] ; then
	usage
	exit 1
fi

INSTALLATION_MODE="install"
if [ ! -z "$upgrade" ] && [ "$upgrade" -eq 1 ]; then
    INSTALLATION_MODE="upgrade"
fi

## Load default input variables
source $INSTALL_DIR/inputvars.default.env
## Load all functions used in this script
source $INSTALL_DIR/functions

## Define a default log file
LOG_FILE=${LOG_FILE:=log\/install_centreon.log}

## Init LOG_FILE
[ ! -d "$LOG_DIR" ] && mkdir -p "$LOG_DIR"
if [ -e "$LOG_FILE" ] ; then
	mv "$LOG_FILE" "$LOG_FILE.`date +%Y%m%d-%H%M%S`"
fi
${CAT} << __EOL__ > "$LOG_FILE"
__EOL__

# Checking installation script requirements
BINARIES="rm cp mv chmod chown echo more mkdir find grep cat sed tr"
binary_fail="0"
# For the moment, I check if all binary exists in PATH.
# After, I must look a solution to use complet path by binary
# for binary in $BINARIES; do
# 	if [ ! -e ${binary} ] ; then 
# 		pathfind_ret "$binary" "PATH_BIN"
# 		if [ "$?" -ne 0 ] ; then
# 			echo_failure "${binary}" "$fail"
# 			binary_fail=1
# 		fi
# 	fi
# done

## Script stop if one binary is not found
if [ "$binary_fail" -eq 1 ] ; then
	echo_info "Please check failed binary and retry"
	exit 1
else
	echo_success "Script requirements" "$ok"
fi

## Search distribution and version
if [ -z "$DISTRIB" ] ; then
    find_os DISTRIB
fi
echo_info "Found distribution" "$DISTRIB"

## Load specific variables based on distribution and version
if [ -f $INSTALL_DIR/inputvars.$DISTRIB.env ]; then
    echo_info "Loading distribution specific input variables" "install/inputvars.$DISTRIB.env"
    source $INSTALL_DIR/inputvars.$DISTRIB.env
fi

## Load specific variables defined by user
if [ -f $INSTALL_DIR/../inputvars.env ]; then
    echo_info "Loading user specific input variables" "inputvars.env"
    source $INSTALL_DIR/../inputvars.env
fi

## Load variables provided in command line
for env_opt in "${env_opts[@]}"; do
    if [[ "${env_opt}" =~ .+=.+ ]] ; then
        variable=$(echo $env_opt | cut -f1 -d "=")
        value=$(echo $env_opt | cut -f2 -d "=")
        if [ ! -z "$variable" ] && [ ! -z "$value" ] ; then
            echo_info "Loading command line input variables" "${variable}=${value}"
            export ${variable}=${value}
        fi
    fi
done

## Check installation mode
if [ -z "$INSTALLATION_TYPE" ] ; then
    echo_failure "Installation mode" "NOT DEFINED"
    exit 1
fi
if [[ ! "${INSTALLATION_TYPE}" =~ ^central|poller$ ]] ; then
    echo_failure "Installation mode" "$INSTALLATION_TYPE"
    exit 1
fi
echo_info "Installation type" "$INSTALLATION_TYPE"
echo_info "Installation mode" "$INSTALLATION_MODE"

## Use TRAPs to call clean_and_exit when user press
## CRTL+C or exec kill -TERM.
trap clean_and_exit SIGINT SIGTERM

## Valid if you are root 
if [ "${FORCE_NO_ROOT:-0}" -ne 0 ]; then
	USERID=$(id -u)
	if [ "$USERID" != "0" ]; then
	    echo -e "You must launch this script using a root user"
	    exit 1
	fi
fi

## Check space of tmp dir
check_tmp_disk_space
if [ "$?" -eq 1 ] ; then
    if [ "$silent_install" -eq 1 ] ; then
        purge_centreon_tmp_dir "silent"
    else
        purge_centreon_tmp_dir
    fi
fi

## Show license if installation is interactive
# if [ "$silent_install" -ne 1 ] ; then 
#     echo_info "\nWelcome to Centreon installation script!"
#     yes_no_default "Should we start?" "$yes"
#     if [ "$?" -ne 0 ] ; then
#         echo_info "Exiting"
#         exit 1
#     fi
# 	echo_info -e "\nYou will now read Centreon Licence.\\n\\tPress enter to continue."
# 	read 
# 	tput clear 
# 	more "$BASE_DIR/LICENSE.md"

# 	yes_no_default "Do you accept the license?" 
# 	if [ "$?" -ne 0 ] ; then 
# 		echo_failure "Installation aborted - License not accepted" "$fail"
# 		exit 1
# 	else
# 		echo_info "License accepted!"
# 	fi
# fi

# Start installation

ERROR_MESSAGE=""
export ERROR_MESSAGE

## Load previous installation input variables if upgrade
if [ "$upgrade" -eq 1 ] ; then
    test_file "$UPGRADE_FILE" "Centreon upgrade file"
    if [ "$?" -eq 0 ] ; then
        echo_info "Loading previous installation input variables" "$UPGRADE_FILE"
        source $UPGRADE_FILE
    else
        echo_failure "Missing previous installation input variables" "$fail"
        echo_info "Either specify it in command line or using UPGRADE_FILE input variable"
        exit 1
	fi
fi

# Centreon installation requirements
echo_title "Centreon installation requirements"

if [[ "${INSTALLATION_TYPE}" =~ ^central|poller$ ]] ; then
    # System
    test_dir_from_var "SUDOERSD_ETC_DIR" "Sudoers directory"
    test_dir_from_var "LOGROTATED_ETC_DIR" "Logrotate directory"
    test_dir_from_var "CROND_ETC_DIR" "Cron directory"
    test_dir_from_var "SNMP_ETC_DIR" "SNMP configuration directory"

    ## Perl information
    find_perl_info
    test_file_from_var "PERL_BINARY" "Perl binary"
    test_dir_from_var "PERL_LIB_DIR" "Perl libraries directory"
fi
if [[ "${INSTALLATION_TYPE}" =~ ^central$ ]] ; then
    ## Centreon
    test_dir "$BASE_DIR/vendor" "Composer dependencies"
    test_dir "$BASE_DIR/www/static" "Frontend application"

    ## System
    test_file_from_var "RRDTOOL_BINARY" "RRDTool binary"
    test_file_from_var "MAIL_BINARY" "Mail binary"

    ## Apache information
    find_apache_info
    test_user_from_var "APACHE_USER" "Apache user"
    test_group_from_var "APACHE_GROUP" "Apache group"
    test_dir_from_var "APACHE_DIR" "Apache directory"
    test_dir_from_var "APACHE_CONF_DIR" "Apache configuration directory"

    ## MariaDB information
    find_mariadb_info
    install_mariadb_conf="1"
    test_dir "$MARIADB_CONF_DIR" "MariaDB configuration directory"
    if [ "$?" -ne 0 ] ; then
        echo_info "Add the following configuration on your database server:"
        echo "$(<$BASE_DIR/install/src/centreon-mysql.cnf)"
        install_mariadb_conf="0"
    fi

    ## PHP information
    find_phpfpm_info
    get_timezone
    test_var "PHP_TIMEZONE" "PHP timezone"
    test_dir_from_var "PHPFPM_LOG_DIR" "PHP FPM log directory"
    test_dir_from_var "PHPFPM_CONF_DIR" "PHP FPM configuration directory"
    test_dir_from_var "PHPFPM_SERVICE_DIR" "PHP FPM service directory"
    test_dir_from_var "PHP_ETC_DIR" "PHP configuration directory"
    test_file_from_var "PHP_BINARY" "PHP binary"
    test_php_version

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
fi

if [ ! -z "$ERROR_MESSAGE" ] ; then
    echo_failure "Installation requirements" "$fail"
    echo_failure "\nErrors:"
    echo_failure "$ERROR_MESSAGE"
    exit 1
fi

echo_success "Installation requirements" "$ok"

## Centreon information
echo_title "Centreon information"

if [[ "${INSTALLATION_TYPE}" =~ ^central|poller$ ]] ; then
    test_var_and_show "CENTREON_INSTALL_DIR" "Centreon installation directory"
    test_var_and_show "CENTREON_ETC_DIR" "Centreon configuration directory"
    test_var_and_show "CENTREON_LOG_DIR" "Centreon log directory"
    test_var_and_show "CENTREON_VARLIB_DIR" "Centreon variable library directory"
    test_var_and_show "CENTREON_PLUGINS_TMP_DIR" "Centreon Plugins temporary directory"
    test_var_and_show "CENTREON_CACHE_DIR" "Centreon cache directory"
    test_var_and_show "CENTREON_RUN_DIR" "Centreon run directory"
    test_var_and_show "CENTREON_USER" "Centreon user"
    test_var_and_show "CENTREON_HOME" "Centreon user home directory"
    test_var_and_show "CENTREON_GROUP" "Centreon group"
    test_var_and_show "CENTREONTRAPD_SPOOL_DIR" "Centreontrapd spool directory"
fi
if [[ "${INSTALLATION_TYPE}" =~ ^central$ ]] ; then
    test_var_and_show "CENTREON_CENTCORE_DIR" "Centreon Centcore directory"
    test_var_and_show "CENTREON_RRD_STATUS_DIR" "Centreon RRD status directory"
    test_var_and_show "CENTREON_RRD_METRICS_DIR" "Centreon RRD metrics directory"
    test_var_and_show "USE_HTTPS" "Use HTTPS configuration"
fi

if [ ! -z "$ERROR_MESSAGE" ] ; then
    echo_failure "\nErrors:"
    echo_failure "$ERROR_MESSAGE"
    exit 1
fi

if [ "$silent_install" -ne 1 ] ; then 
    yes_no_default "Everything looks good, proceed to installation?"
    if [ "$?" -ne 0 ] ; then
        purge_centreon_tmp_dir "silent"
        exit 1
    fi
fi

# Start installation

## Disconnect user if upgrade
if [ "$upgrade" = "1" ] && [[ "$INSTALLATION_TYPE" =~ central ]] ; then
    echo_info "Disconnect users from WebUI"
    php $INSTALL_DIR/clean_session.php "$CENTREON_ETC" >> "$LOG_FILE" 2>&1
    check_result $? "All users are disconnected"
fi

## Create a random APP_SECRET key
HEX_KEY=($(dd if=/dev/urandom bs=32 count=1 status=none | $PHP_BINARY -r "echo bin2hex(fread(STDIN, 32));"));

## Build files
echo_title "Build files"
echo_info "Copying files to '$TMP_DIR'"

if [ -d $TMP_DIR ] ; then
    echo_info "Directory '$TMP_DIR' already exists, moving it..."
    mv $TMP_DIR $TMP_DIR.`date +%Y%m%d-%k%m%S`
fi

create_dir "$TMP_DIR/source"

if [[ "${INSTALLATION_TYPE}" =~ ^central|poller$ ]] ; then
    {
        copy_dir "$BASE_DIR/bin" "$TMP_DIR/source/" &&
        copy_dir "$BASE_DIR/cron" "$TMP_DIR/source/" &&
        copy_dir "$BASE_DIR/logrotate" "$TMP_DIR/source/" &&
        copy_dir "$BASE_DIR/snmptrapd" "$TMP_DIR/source/" &&
        copy_dir "$BASE_DIR/tmpl" "$TMP_DIR/source/" &&
        copy_dir "$BASE_DIR/install" "$TMP_DIR/source/"
    } || {
        echo_failure "Error when copying files to '$TMP_DIR'" "$fail"
        purge_centreon_tmp_dir "silent"
        exit 1
    }
fi
if [[ "${INSTALLATION_TYPE}" =~ ^central$ ]] ; then
    {
        copy_dir "$BASE_DIR/config" "$TMP_DIR/source/" &&
        copy_dir "$BASE_DIR/GPL_LIB" "$TMP_DIR/source/" &&
        copy_dir "$BASE_DIR/lib" "$TMP_DIR/source/" &&
        copy_dir "$BASE_DIR/src" "$TMP_DIR/source/" &&
        copy_dir "$BASE_DIR/vendor" "$TMP_DIR/source/" &&
        copy_dir "$BASE_DIR/www" "$TMP_DIR/source/" &&
        copy_dir "$BASE_DIR/api" "$TMP_DIR/source/" &&
        copy_file "$BASE_DIR/.env" "$TMP_DIR/source/" &&
        copy_file "$BASE_DIR/.env.local.php" "$TMP_DIR/source/" &&
        copy_file "$BASE_DIR/bootstrap.php" "$TMP_DIR/source/" &&
        copy_file "$BASE_DIR/container.php" "$TMP_DIR/source/" &&
        copy_file "$BASE_DIR/package.json" "$TMP_DIR/source/" &&
        copy_file "$BASE_DIR/composer.json" "$TMP_DIR/source/"
    } || {
        echo_failure "Error when copying files to '$TMP_DIR'" "$fail"
        purge_centreon_tmp_dir "silent"
        exit 1
    }
fi

echo_info "Replacing macros"
{
    if [[ "${INSTALLATION_TYPE}" =~ ^central|poller$ ]] ; then
        replace_macro "bin cron logrotate snmptrapd tmpl install"
    fi
    if [[ "${INSTALLATION_TYPE}" =~ ^central$ ]] ; then
        replace_macro "config www .env .env.local.php"
    fi
} || {
    echo_failure "Error when replacing macros" "$fail"
    purge_centreon_tmp_dir "silent"
    exit 1
}

echo_info "Building installation tree"
BUILD_DIR="$TMP_DIR/build"
create_dir "$BUILD_DIR"

if [[ "${INSTALLATION_TYPE}" =~ ^central|poller$ ]] ; then
    {
        # Create user and group
        create_group "$CENTREON_GROUP" &&
        create_user "$CENTREON_USER" "$CENTREON_GROUP" "$CENTREON_HOME" &&

        # Centreon configuration
        create_dir "$BUILD_DIR/$CENTREON_ETC_DIR" "$CENTREON_USER" "$CENTREON_GROUP" "775" &&
        create_dir "$BUILD_DIR/$CENTREON_ETC_DIR/config.d" "$CENTREON_USER" "$CENTREON_GROUP" "775" &&
        copy_file "$TMP_DIR/source/www/install/var/config.yaml" "$BUILD_DIR/$CENTREON_ETC_DIR/config.yaml" \
            "$CENTREON_USER" "$CENTREON_GROUP" "664" &&

        ### Log directory
        create_dir "$BUILD_DIR/$CENTREON_LOG_DIR" "$CENTREON_USER" "$CENTREON_GROUP" "775" &&

        ### Variable libraries directory
        create_dir "$BUILD_DIR/$CENTREON_VARLIB_DIR" "$CENTREON_USER" "$CENTREON_GROUP" "775" &&
        create_dir "$BUILD_DIR/$CENTREON_PLUGINS_TMP_DIR" "$CENTREON_USER" "$CENTREON_GROUP" "775" &&

        ### Run directory
        create_dir "$BUILD_DIR/$CENTREON_RUN_DIR" "$CENTREON_USER" "$CENTREON_GROUP" "775" &&

        ### Cache directories
        create_dir "$BUILD_DIR/$CENTREON_CACHE_DIR" "$CENTREON_USER" "$CENTREON_GROUP" "775" &&
        create_dir "$BUILD_DIR/$CENTREON_CACHE_DIR/backup" "$CENTREON_USER" "$CENTREON_GROUP" "750" &&
        create_dir "$BUILD_DIR/$CENTREON_CACHE_DIR/config/engine" "$CENTREON_USER" "$CENTREON_GROUP" "775" &&
        create_dir "$BUILD_DIR/$CENTREON_CACHE_DIR/config/broker" "$CENTREON_USER" "$CENTREON_GROUP" "775" &&
        create_dir "$BUILD_DIR/$CENTREON_CACHE_DIR/config/export" "$CENTREON_USER" "$CENTREON_GROUP" "775" &&

        ### Centreon binaries
        create_dir "$BUILD_DIR/$CENTREON_INSTALL_DIR" "" "" "755" &&
        create_dir "$BUILD_DIR/$CENTREON_INSTALL_DIR/bin" "" "" "755" &&
        copy_file "$TMP_DIR/source/bin/centreontrapd" "$BUILD_DIR/$CENTREON_INSTALL_DIR/bin/centreontrapd" \
            "" "" "755" &&
        copy_file "$TMP_DIR/source/bin/centreontrapdforward" \
            "$BUILD_DIR/$CENTREON_INSTALL_DIR/bin/centreontrapdforward" "" "" "755" &&
        copy_file "$TMP_DIR/source/bin/registerServerTopology.sh" \
            "$BUILD_DIR/$CENTREON_INSTALL_DIR/bin/registerServerTopology.sh" "" "" "755" &&
        copy_file "$TMP_DIR/source/bin/registerServerTopologyTemplate" \
            "$BUILD_DIR/$CENTREON_INSTALL_DIR/bin/registerServerTopologyTemplate" "" "" "644" &&

        ### Perl libraries
        create_dir "$BUILD_DIR/$PERL_LIB_DIR" &&
        copy_dir "$TMP_DIR/source/lib/perl/centreon" "$BUILD_DIR/$PERL_LIB_DIR/centreon" &&

        ### Sudoers configuration
        create_dir "$BUILD_DIR/$SUDOERSD_ETC_DIR" "" "" "440" &&
        copy_file "$TMP_DIR/source/tmpl/install/sudoersCentreonEngine" "$BUILD_DIR/$SUDOERSD_ETC_DIR/centreon" \
            "" "" "600"
    } || {
        echo_failure "Error building files" "$fail"
        purge_centreon_tmp_dir "silent"
        exit 1
    }
fi
if [[ "${INSTALLATION_TYPE}" =~ ^central$ ]] ; then
    {
        # Centreon configuration
        copy_file "$TMP_DIR/source/install/src/instCentWeb.conf" \
            "$BUILD_DIR/$CENTREON_ETC_DIR/instCentWeb.conf" \
            "$CENTREON_USER" "$CENTREON_GROUP" "644" &&

        ### Variable libraries directory
        create_dir "$BUILD_DIR/$CENTREON_VARLIB_DIR/installs" "$CENTREON_USER" "$CENTREON_GROUP" "775" &&
        create_dir "$BUILD_DIR/$CENTREON_VARLIB_DIR/log" "$CENTREON_USER" "$CENTREON_GROUP" "775" &&
        create_dir "$BUILD_DIR/$CENTREON_VARLIB_DIR/nagios-perf" "$CENTREON_USER" "$CENTREON_GROUP" "775" &&
        create_dir "$BUILD_DIR/$CENTREON_VARLIB_DIR/perfdata" "$CENTREON_USER" "$CENTREON_GROUP" "775" &&
        create_dir "$BUILD_DIR/$CENTREON_CENTCORE_DIR" "$CENTREON_USER" "$CENTREON_GROUP" "775" &&
        create_dir "$BUILD_DIR/$CENTREON_RRD_STATUS_DIR" "$CENTREON_USER" "$CENTREON_GROUP" "775" &&
        create_dir "$BUILD_DIR/$CENTREON_RRD_METRICS_DIR" "$CENTREON_USER" "$CENTREON_GROUP" "775" &&

        ### Symfony cache directory
        create_dir "$BUILD_DIR/$CENTREON_CACHE_DIR/symfony" "$APACHE_USER" "$APACHE_GROUP" "755" &&

        ### Web directory
        copy_dir "$TMP_DIR/source/www" "$BUILD_DIR/$CENTREON_INSTALL_DIR/www" \
            "$CENTREON_USER" "$CENTREON_GROUP" "775" &&
        copy_file "$TMP_DIR/source/install/src/install.conf.php" \
            "$BUILD_DIR/$CENTREON_INSTALL_DIR/www/install/install.conf.php" \
            "$CENTREON_USER" "$CENTREON_GROUP" "775" &&
        create_dir "$BUILD_DIR/$CENTREON_INSTALL_DIR/www/modules" "$CENTREON_USER" "$CENTREON_GROUP" "775" &&

        ### Sources
        copy_dir "$TMP_DIR/source/src" "$BUILD_DIR/$CENTREON_INSTALL_DIR/src" \
            "$CENTREON_USER" "$CENTREON_GROUP" "775" &&

        ### API files
        copy_dir "$TMP_DIR/source/api" "$BUILD_DIR/$CENTREON_INSTALL_DIR/api" \
            "$CENTREON_USER" "$CENTREON_GROUP" "775" &&

        ### Symfony config directories
        copy_dir "$TMP_DIR/source/vendor" "$BUILD_DIR/$CENTREON_INSTALL_DIR/vendor" "" "" "755" &&
        copy_dir "$TMP_DIR/source/config" "$BUILD_DIR/$CENTREON_INSTALL_DIR/config" "" "" "755" &&
        copy_file "$BUILD_DIR/$CENTREON_INSTALL_DIR/config/centreon.config.php.template" \
            "$BUILD_DIR/$CENTREON_INSTALL_DIR/config/centreon.config.php" "" "" "644" &&

        ### Smarty directories
        copy_dir "$TMP_DIR/source/GPL_LIB" "$BUILD_DIR/$CENTREON_INSTALL_DIR/GPL_LIB" "" "" "755" &&
        set_ownership "$BUILD_DIR/$CENTREON_INSTALL_DIR/GPL_LIB/SmartyCache" "$CENTREON_USER" "$CENTREON_GROUP" &&
        set_permissions "$BUILD_DIR/$CENTREON_INSTALL_DIR/GPL_LIB/SmartyCache" "775" &&

        ### Centreon binaries
        create_dir "$BUILD_DIR/usr/bin" "" "" "555" &&
        copy_file "$TMP_DIR/source/bin/centFillTrapDB" \
            "$BUILD_DIR/$CENTREON_INSTALL_DIR/bin/centFillTrapDB" "" "" "755" &&
        copy_file "$TMP_DIR/source/bin/centreon_health" \
            "$BUILD_DIR/$CENTREON_INSTALL_DIR/bin/centreon_health" "" "" "755" &&
        copy_file "$TMP_DIR/source/bin/centreon_trap_send" \
            "$BUILD_DIR/$CENTREON_INSTALL_DIR/bin/centreon_trap_send" "" "" "755" &&
        copy_file "$TMP_DIR/source/bin/centreonSyncPlugins" \
            "$BUILD_DIR/$CENTREON_INSTALL_DIR/bin/centreonSyncPlugins" "" "" "755" &&
        copy_file "$TMP_DIR/source/bin/centreonSyncArchives" \
            "$BUILD_DIR/$CENTREON_INSTALL_DIR/bin/centreonSyncArchives" "" "" "755" &&
        copy_file "$TMP_DIR/source/bin/generateSqlLite" \
            "$BUILD_DIR/$CENTREON_INSTALL_DIR/bin/generateSqlLite" "" "" "755" &&
        copy_file "$TMP_DIR/source/bin/changeRrdDsName.pl" \
            "$BUILD_DIR/$CENTREON_INSTALL_DIR/bin/changeRrdDsName.pl" "" "" "755" &&
        copy_file "$TMP_DIR/source/bin/migrateWikiPages.php" \
            "$BUILD_DIR/$CENTREON_INSTALL_DIR/bin/migrateWikiPages.php" "" "" "644" &&
        copy_file "$TMP_DIR/source/bin/centreon-partitioning.php" \
            "$BUILD_DIR/$CENTREON_INSTALL_DIR/bin/centreon-partitioning.php" "" "" "644" &&
        copy_file "$TMP_DIR/source/bin/logAnalyserBroker" \
            "$BUILD_DIR/$CENTREON_INSTALL_DIR/bin/logAnalyserBroker" "" "" "755" &&
        create_symlink "$CENTREON_INSTALL_DIR/bin/centFillTrapDB" \
            "$BUILD_DIR/usr/bin/centFillTrapDB" &&
        create_symlink "$CENTREON_INSTALL_DIR/bin/centreon_trap_send" \
            "$BUILD_DIR/usr/bin/centreon_trap_send" &&
        create_symlink "$CENTREON_INSTALL_DIR/bin/centreonSyncPlugins" \
            "$BUILD_DIR/usr/bin/centreonSyncPlugins" &&
        create_symlink "$CENTREON_INSTALL_DIR/bin/centreonSyncArchives" \
            "$BUILD_DIR/usr/bin/centreonSyncArchives" &&
        create_symlink "$CENTREON_INSTALL_DIR/bin/generateSqlLite" \
            "$BUILD_DIR/usr/bin/generateSqlLite" &&
        copy_file "$TMP_DIR/source/bin/import-mysql-indexes" \
            "$BUILD_DIR/$CENTREON_INSTALL_DIR/bin/import-mysql-indexes" \
            "$CENTREON_USER" "$CENTREON_GROUP" "755" &&
        copy_file "$TMP_DIR/source/bin/export-mysql-indexes" \
            "$BUILD_DIR/$CENTREON_INSTALL_DIR/bin/export-mysql-indexes" \
            "$CENTREON_USER" "$CENTREON_GROUP" "755" &&
        copy_file "$TMP_DIR/source/bin/centreon" "$BUILD_DIR/$CENTREON_INSTALL_DIR/bin/centreon" \
            "$CENTREON_USER" "$CENTREON_GROUP" "755" &&
        copy_file "$TMP_DIR/source/bin/console" "$BUILD_DIR/$CENTREON_INSTALL_DIR/bin/console" \
            "$CENTREON_USER" "$CENTREON_GROUP" "755" &&
        create_symlink "$CENTREON_INSTALL_DIR/bin/centreon" "$BUILD_DIR/usr/bin/centreon" \
            "$CENTREON_USER" "$CENTREON_GROUP" &&

        ### Centreon CLAPI
        create_dir "$BUILD_DIR/$CENTREON_INSTALL_DIR/lib" "" "" "755" &&
        copy_file "$TMP_DIR/source/lib/Slug.class.php" "$BUILD_DIR/$CENTREON_INSTALL_DIR/lib/Slug.class.php" \
            "" "" "644" &&
        copy_dir "$TMP_DIR/source/lib/Centreon" "$BUILD_DIR/$CENTREON_INSTALL_DIR/lib/Centreon" "" "" "755" &&

        ### Cron binary
        copy_dir "$TMP_DIR/source/cron" "$BUILD_DIR/$CENTREON_INSTALL_DIR/cron" "" "" "775" &&

        ### Bases
        copy_file "$TMP_DIR/source/bootstrap.php" "$BUILD_DIR/$CENTREON_INSTALL_DIR/bootstrap.php" "" "" "644" &&
        copy_file "$TMP_DIR/source/composer.json" "$BUILD_DIR/$CENTREON_INSTALL_DIR/composer.json" "" "" "644" &&
        copy_file "$TMP_DIR/source/container.php" "$BUILD_DIR/$CENTREON_INSTALL_DIR/container.php" "" "" "644" &&
        copy_file "$TMP_DIR/source/package.json" "$BUILD_DIR/$CENTREON_INSTALL_DIR/package.json" "" "" "644" &&

        ### Cron configurations
        create_dir "$BUILD_DIR/$CROND_ETC_DIR" "" "" "775" &&
        copy_file "$TMP_DIR/source/tmpl/install/centreon.cron" "$BUILD_DIR/$CROND_ETC_DIR/centreon" \
            "" "" "644" &&
        copy_file "$TMP_DIR/source/tmpl/install/centstorage.cron" "$BUILD_DIR/$CROND_ETC_DIR/centstorage" \
            "" "" "644"
    } || {
        echo_failure "Error building files" "$fail"
        purge_centreon_tmp_dir "silent"
        exit 1
    }
fi

## Install files
echo_title "Install files"
echo_info "Copying files from '$TMP_DIR' to final directory"
copy_dir "$BUILD_DIR/*" "/"
if [ "$?" -ne 0 ] ; then
    echo_failure "Error when copying files" "$fail"
    purge_centreon_tmp_dir "silent"
    exit 1
fi

## Update groups memberships
echo_title "Update groups memberships"
if [[ "${INSTALLATION_TYPE}" =~ ^central|poller$ ]] ; then
    add_user_to_group "$ENGINE_USER" "$CENTREON_GROUP"
    add_user_to_group "$CENTREON_USER" "$ENGINE_GROUP"
    add_user_to_group "$ENGINE_USER" "$BROKER_GROUP"
    add_user_to_group "$BROKER_USER" "$CENTREON_GROUP"
    add_user_to_group "$CENTREON_USER" "$GORGONE_GROUP"
    add_user_to_group "$GORGONE_USER" "$CENTREON_GROUP"
    add_user_to_group "$GORGONE_USER" "$BROKER_GROUP"
    add_user_to_group "$GORGONE_USER" "$ENGINE_GROUP"
fi
if [[ "${INSTALLATION_TYPE}" =~ ^central$ ]] ; then
    add_user_to_group "$APACHE_USER" "$CENTREON_GROUP"
    add_user_to_group "$APACHE_USER" "$ENGINE_GROUP"
    add_user_to_group "$APACHE_USER" "$BROKER_GROUP"
    add_user_to_group "$APACHE_USER" "$GORGONE_GROUP"
    add_user_to_group "$GORGONE_USER" "$APACHE_GROUP"
    add_user_to_group "$CENTREON_USER" "$APACHE_GROUP"
fi

## Configure services
echo_title "Configure services"

if [[ "${INSTALLATION_TYPE}" =~ ^central|poller$ ]] ; then
    ### Centreon
    copy_file "$TMP_DIR/source/tmpl/install/redhat/centreon.systemd" "$SYSTEMD_ETC_DIR/centreon.service"
    copy_file_no_replace "$TMP_DIR/source/logrotate/centreon" "$LOGROTATED_ETC_DIR/centreon" \
        "Logrotate Centreon configuration"
    enable_service "centreon"

    ### Centreontrapd
    copy_file "$TMP_DIR/source/tmpl/install/redhat/centreontrapd.systemd" "$SYSTEMD_ETC_DIR/centreontrapd.service"
    copy_file "$TMP_DIR/source/snmptrapd/snmptrapd.conf" "$SNMP_ETC_DIR/snmptrapd.conf"
    copy_file "$TMP_DIR/source/install/src/centreontrapd.pm" "$CENTREON_ETC_DIR/centreontrapd.pm" \
        "$CENTREON_USER" "$CENTREON_GROUP" "644"
    create_dir "$SNMP_ETC_DIR/centreon_traps" "$CENTREON_USER" "$CENTREON_GROUP" "775"
    create_dir "$CENTREONTRAPD_SPOOL_DIR" "$CENTREON_USER" "$CENTREON_GROUP" "755"
    copy_file_no_replace "$TMP_DIR/source/logrotate/centreontrapd" "$LOGROTATED_ETC_DIR/centreontrapd" \
        "Logrotate Centreontrapd configuration"
    deploy_sysconfig "centreontrapd" "$TMP_DIR/source/tmpl/install/redhat/centreontrapd.sysconfig"
    enable_service "centreontrapd"

    ### Gorgone
    copy_file_no_replace "$TMP_DIR/source/install/src/gorgoneRootConfigTemplate.yaml" \
        "$GORGONE_ETC_DIR/config.d/30-centreon.yaml" "Gorgone configuration" \
        "$GORGONE_USER" "$GORGONE_GROUP" "644"
fi
if [[ "${INSTALLATION_TYPE}" =~ ^central$ ]] ; then
    ### Symfony
    copy_file_no_replace "$TMP_DIR/source/.env" "$CENTREON_INSTALL_DIR" "Symfony .env"
    copy_file_no_replace "$TMP_DIR/source/.env.local.php" "$CENTREON_INSTALL_DIR" "Symfony .env.local.php"

    ### Apache
    reload_apache="0"
    if [ $USE_HTTPS -eq 1 ] ; then
        copy_file_no_replace "$TMP_DIR/source/install/src/centreon-apache-https.conf" \
            "$APACHE_CONF_DIR/10-centreon.conf" "Apache configuration"
        if [ "$?" -eq 0 ] ; then reload_apache="1" ; fi
    else
        copy_file_no_replace "$TMP_DIR/source/install/src/centreon-apache.conf" \
            "$APACHE_CONF_DIR/10-centreon.conf" "Apache configuration"
        if [ "$?" -eq 0 ] ; then reload_apache="1" ; fi
    fi

    ### PHP FPM
    restart_php_fpm="0"
    create_dir "$PHPFPM_VARLIB_DIR/session" "root" "$APACHE_USER" "770"
    create_dir "$PHPFPM_VARLIB_DIR/wsdlcache" "root" "$APACHE_USER" "775"
    copy_file_no_replace "$TMP_DIR/source/install/src/php-fpm.conf" "$PHPFPM_CONF_DIR/centreon.conf" \
        "PHP FPM configuration"
    if [ "$?" -eq 0 ] ; then restart_php_fpm="1" ; fi
    copy_file_no_replace "$TMP_DIR/source/install/src/php-fpm-systemd.conf" "$PHPFPM_SERVICE_DIR/centreon.conf" \
        "PHP FPM service configuration"
    if [ "$?" -eq 0 ] ; then restart_php_fpm="1" ; fi
    copy_file_no_replace "$TMP_DIR/source/install/src/php.ini" "$PHP_ETC_DIR/50-centreon.ini" "PHP configuration"
    if [ "$?" -eq 0 ] ; then restart_php_fpm="1" ; fi

    ### MariaDB
    restart_mariadb="0"
    if [ $install_mariadb_conf -eq 1 ] ; then
        copy_file_no_replace "$TMP_DIR/source/install/src/centreon-mysql.cnf" "$MARIADB_CONF_DIR/centreon.cnf" \
            "MariaDB configuration"
        if [ "$?" -eq 0 ] ; then restart_mariadb="1" ; fi
        copy_file_no_replace "$TMP_DIR/source/install/src/mariadb-systemd.conf" "$MARIADB_SERVICE_DIR/centreon.conf" \
            "MariaDB service configuration"
        if [ "$?" -eq 0 ] ; then restart_mariadb="1" ; fi
    fi

    if [ "$reload_apache" -eq 1 ] || [ "$restart_php_fpm" -eq 1 ] || [ "$restart_mariadb" -eq 1 ] ; then
        reload_daemon
    fi

    if [ "$reload_apache" -eq 1 ] ; then
        enable_conf "10-centreon"
        enable_service "$APACHE_SERVICE"
        reload_service "$APACHE_SERVICE"
    fi
    if [ "$restart_php_fpm" -eq 1 ] ; then
        enable_service "$PHPFPM_SERVICE"
        restart_service "$PHPFPM_SERVICE"
    fi
    if [ "$restart_mariadb" -eq 1 ] ; then
        enable_service "$MARIADB_SERVICE"
        restart_service "$MARIADB_SERVICE"
    fi
fi

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
