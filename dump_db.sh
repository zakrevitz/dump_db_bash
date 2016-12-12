#!/bin/bash
# Error codes
readonly ENOENT=10  # No such file or directory

ME=`basename $0`
PREFIX="config_"
# Commands for formatted output
red=$(tput setf 4)
green=$(tput setf 2)
reset=$(tput sgr0)
toend=$(tput hpa $(tput cols))$(tput cub 6)

parse_opts() {
  while getopts ":hcb:f:" opt ;
  do
    case $opt in
      b) set_branch $OPTARG;
         set_variables $BRANCH
          ;;
      c) COPY=true;
          ;;
      f) FILE_NAME=$OPTARG;
          ;;
      h) print_help;
          exit 1
          ;;
      *) echo "Wrong argument";
          echo "To who help just type $ME -h";
          exit 1
          ;;
      esac
  done
}

print_help() {
  echo "PG dump DB"
  echo
  echo "Usage: $ME [arguments]"
  echo "Arguments:"
  echo -e "  -c\t\tCopy db/dump.sql → public/dump.sql"
  echo -e "  -b\t\tDefine environment, available dev/test/prod/stag. Default: prod"
  echo -e "  -f\t\tSet file name. Default: dump.sql"
  echo -e "  -h\t\tShow this message."
  echo
  echo "Exit codes:"
  echo "  0 - it\`s okay"
  echo "  1 - minor errors"
  echo "  10 - file not found"
}


defaults() {
  FILE_NAME='dump.sql';
  BRANCH=$PREFIX"production";
  COPY=false;
  set_variables $BRANCH
}

set_variables() {
  # TODO: Seriously...do we need this low-level sh&t?
  PASSWORD=$1"_password"
  DATABASE=$1"_database"
  USERNAME=$1"_username"
}

set_branch() {
  case "$1" in
    prod)
        BRANCH=$PREFIX"production"
        ;;

    dev)
        BRANCH=$PREFIX"development"
        ;;

    test)
        BRANCH=$PREFIX"test"
        ;;
    stag)
        BRANCH=$PREFIX"staging"
        ;;
    *)
        echo $"Available branches: {prod|dev|test|stag}${red}${toend}[FAIL]"
        exit 1
  esac
}

check_config_file() {
  if [ ! -f config/database.yml ]; then
    echo -en "DB config file not found! Check config/database.yml${red}${toend}[FAIL]\n"
    exit "$ENOENT" # Exits whole script with error code
  fi
  echo "Config file...${green}${toend}[OK]"
  echo "${reset}"
}

check_parameters() {
  if [ -z "${!DATABASE}" ]; then
    parsing_error "Database name"
  elif [ -z "${!USERNAME}" ]; then
    parsing_error "Username"
  elif [ -z "${!PASSWORD}" ]; then
    parsing_error "Password"
  fi
  echo "Database params...${green}${toend}[OK]"
  echo "${reset}"
}

parsing_error() {
  echo "Invalid database.yml"
  echo "$1 is invalid/missing${red}${toend}[FAIL]"
  exit 1
}

# Credits to https://gist.github.com/pkuczynski/8665367
# Change to 4-spaces indent
# indent = length($1)/2; → indent = length($1)/7;
parse_yaml() {
  local prefix=$2
  local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034'|tr -d '\015')
  sed -ne "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" \
      -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
  awk -F$fs '{
    indent = length($1)/2;
    vname[indent] = $2;
    for (i in vname) {if (i > indent) {delete vname[i]}}
    if (length($3) > 0) {
       vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
       printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
    }
  }'
}

copy_to_public() {
  sudo cp db/$FILE_NAME public/$FILE_NAME
  echo "File copied...${green}${toend}[OK]"
  echo "${reset}"
}

dump_db () {
  check_config_file
  # TODO: change this to proper way
  eval $(parse_yaml config/database.yml $PREFIX)
  check_parameters

  export PGPASSWORD="${!PASSWORD}"
  pg_dump -U ${!USERNAME} -h localhost ${!DATABASE} > db/$FILE_NAME
  echo "Dumping database...${green}${toend}[OK]"
  echo "${reset}"
  if [ "$COPY" = true ]; then
    copy_to_public
  fi
}

# Function queue
defaults
parse_opts $@
dump_db
