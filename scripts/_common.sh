#!/bin/bash

#=================================================
# COMMON VARIABLES
#=================================================

#=================================================
# PERSONAL HELPERS
#=================================================

#=================================================
# EXPERIMENTAL HELPERS
#=================================================

# Create a dedicated config file from a template
#
# usage: ynh_add_config --template="template" --destination="destination"
# | arg: -t, --template=     - Template config file to use
# | arg: -d, --destination=    - Destination of the config file
#
# examples:
#    ynh_add_config --template=".env" --destination="$install_dir/.env" use the template file "../conf/.env"
#    ynh_add_config --template="/etc/nginx/sites-available/default" --destination="etc/nginx/sites-available/mydomain.conf"
#
# The template can be by default the name of a file in the conf directory
# of a YunoHost Package, a relative path or an absolute path.
#
# The helper will use the template `template` to generate a config file
# `destination` by replacing the following keywords with global variables
# that should be defined before calling this helper :
# ```
#   __PATH__                by $path_url
#   __NAME__                by $app
#   __NAMETOCHANGE__        by $app
#   __USER__                by $app
#   __INSTALL_DIR__           by $final_path
#   __PHPVERSION__          by $YNH_PHP_VERSION (packaging v1 only, packaging v2 uses phpversion setting implicitly set by apt resource)
#   __YNH_NODE_LOAD_PATH__  by $ynh_node_load_PATH
# ```
# And any dynamic variables that should be defined before calling this helper like:
# ```
#   __DOMAIN__   by $domain
#   __APP__      by $app
#   __VAR_1__    by $var_1
#   __VAR_2__    by $var_2
# ```
#
# The helper will verify the checksum and backup the destination file
# if it's different before applying the new template.
#
# And it will calculate and store the destination file checksum
# into the app settings when configuration is done.
#
# Requires YunoHost version 4.1.0 or higher.

ynh_add_config_exp() {
    # Declare an array to define the options of this helper.
    local legacy_args=tdv
    local -A args_array=([t]=template= [d]=destination=)
    local template
    local destination
    # Manage arguments with getopts
    ynh_handle_getopts_args "$@"
    local template_path

    if [ -f "$YNH_APP_BASEDIR/conf/$template" ]; then
        template_path="$YNH_APP_BASEDIR/conf/$template"
    elif [ -f "$template" ]; then
        template_path=$template
    else
        ynh_die --message="The provided template $template doesn't exist"
    fi

    # Backup variables handled by the config panel
    local configpanel_backup_path
    configpanel_backup_path=$(mktemp)
    yunohost app config get $app --export > $configpanel_backup_path

    ynh_backup_if_checksum_is_different --file="$destination"

    # Make sure to set the permissions before we copy the file
    # This is to cover a case where an attacker could have
    # created a file beforehand to have control over it
    # (cp won't overwrite ownership / modes by default...)
    touch $destination
    chown root:root $destination
    chmod 640 $destination

    cp -f "$template_path" "$destination"

    _ynh_apply_default_permissions $destination

    ynh_replace_vars --file="$destination"

    ynh_store_file_checksum --file="$destination"

    # Restore variables handled by the config panel
    yunohost app config set $app -f $configpanel_backup_path --debug

    ynh_store_file_checksum --file="$destination"
}
