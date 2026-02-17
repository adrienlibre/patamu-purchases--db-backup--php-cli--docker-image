#!/bin/bash
#
# Library for managing files

# shellcheck disable=SC1091

# Global variables

declare -A laravel_env_array
declare -A os_env_array
readonly SOURCE_DIRECTORY="/source"

# Functions

########################
# Generate the .env file based on environment variables
# Returns:
#   None
#########################
generate_env_file() {
    # read the env file and populate laravel_env_array
    parse_env_file "/run/secrets/environment-file"
    # parse the env templates and append the result to the .env file
    parse_env_templates "/patamu/templates/laravel/env"
    # change the ownership of the .env file to www-data
    chown www-data:www-data "$SOURCE_DIRECTORY/.env"
}

########################
# return the default value of a property
# Arguments:
#   $1 - default value
# Returns:
#   String
#########################
get_default_value() {
    local default="${1:-}"
    if [[ "$default" =~ \<[[:alnum:]_]*\> ]]; then
        # the string contains a keyword
        local keyword=$(echo "$default" | grep -o '<[[:alnum:]_]*>')
        # using declare because of variable indirection (the variable env_var_name contains the name a variable)
        declare env_var_name=$(echo "$keyword" | sed 's/[<>]//g')

        # check whether the env_var exists; if it doesn't, leave the default value as it is
        if [[ -v os_env_array["$env_var_name"] ]]; then
            local env_var_value=${os_env_array["$env_var_name"]}
            default=$(echo "$default" | sed "s#$keyword#$env_var_value#g")
        fi
    fi

    echo "$default"
}

########################
# initialize the associative array os_env_array with the os environment variables
# Returns:
#   None
#########################
init_os_env_array() {
# Populate the associative array with environment variables
    while IFS= read -r line; do
        local key=${line%%=*}
        local value=${line#*=}
        os_env_array["$key"]=$value
    done < <(printenv)
}

########################
# Parse the env file and populate the global associative array 'laravel_env_array'
# Arguments:
#   $1 - path to the env file
# Returns:
#   None
#########################
parse_env_file() {
    local env_file="$1"

    while IFS='=' read -r key value; do
        if [[ -n "$key" && ! "$key" =~ ^\#.*$ ]]; then
            laravel_env_array["$key"]=$value
        fi
    done < "$env_file"
}

########################
# Parse a template file
# Arguments:
#   $1 - directory
# Returns:
#   None
#########################
parse_env_template() {
    init_os_env_array

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ -z "${line// }" ]]; then
            continue
        fi

        local default=""
        local key=$(echo "$line" | cut -d'=' -f1)
        local value=$(echo "$line" | cut -d'=' -f2)

        if [[ $value == *","* ]]; then
            local valueAux=$(echo "$value" | cut -d',' -f1)
            default=$(get_default_value $(echo "$value" | cut -d',' -f2))
            value=$valueAux
        fi

        value=$(echo "$value" | tr -d '<>')

        # Check if the key exists in the array
        if [[ -v laravel_env_array[$value] ]]; then
            # check whether the laravel_env_array has a value for the key, if not, use the default value
            if [[ -z "${laravel_env_array[$value]}" ]]; then
                echo "$key=$default" >> "$SOURCE_DIRECTORY/.env"
            else
                echo "$key=${laravel_env_array[$value]}" >> "$SOURCE_DIRECTORY/.env"
            fi
        else
            # key doesn't exist in laravel_env_array
            # if there's no comma in the template, the variable is required
            if [[ "$line" != *","* ]]; then
                echo "ERROR: Required environment variable '$value' is not provided in the environment file" >&2
                exit 1
            fi
            echo "$key=$default" >> "$SOURCE_DIRECTORY/.env"
        fi

    done < "$1"
    echo "" >> "$SOURCE_DIRECTORY/.env"
}

########################
# Parse a directory and execute a function for each found file
# Arguments:
#   $1 - directory
# Returns:
#   None
#########################
parse_env_templates() {
    for file in "$1"/*; do
        if [[ -f "$file" ]]; then
            # call another function here with $file as argument
            parse_env_template "$file"
        fi
    done
}

########################
# Replace a regex-matching string in a file
# Arguments:
#   $1 - filename
#   $2 - match regex
#   $3 - substitute regex
#   $4 - use POSIX regex. Default: true
# Returns:
#   None
#########################
replace_in_file() {
    local filename="${1:?filename is required}"
    local match_regex="${2:?match regex is required}"
    local substitute_regex="${3:-}"
    local posix_regex=${4:-true}

    local result
    
    # Check if substitute_regex is empty or not provided
    if [ -z "$substitute_regex" ]; then
        return  # Return without specifying an error code
    fi

    # We should avoid using 'sed in-place' substitutions
    # 1) They are not compatible with files mounted from ConfigMap(s)
    # 2) We found incompatibility issues with Debian10 and "in-place" substitutions
    local -r del=$'\001' # Use a non-printable character as a 'sed' delimiter to avoid issues
    if [[ $posix_regex = true ]]; then
        result="$(sed -E "s${del}${match_regex}${del}${substitute_regex}${del}g" "$filename")"
    else
        result="$(sed "s${del}${match_regex}${del}${substitute_regex}${del}g" "$filename")"
    fi
    echo "$result" > "$filename"
}
