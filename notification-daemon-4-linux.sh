#!/bin/bash 
#############################################
#     __    ____________________  _____  __ #
#    / /   /  _/ ____/ ____/ __ \/   \ \/ / #
#   / /    / // /_  / __/ / /_/ / /| |\  /  #
#  / /____/ // __/ / /___/ _, _/ ___ |/ /   #
# /_____/___/_/   /_____/_/ |_/_/  |_/_/    #
# 	 										#
#############################################
# 	 										#
#	DXP Notification Daemon for Linux 1.0	#
#	martin.dominguez@liferay.com			#
# 	 										#
#	Version history:						#
#	 06-02-2020 | 1.0 | Initial Commit		#
# 	 										#
#############################################
# 	 										#
# Requirements:                             #
#   -> Requires curl 7.18.0 or newer        #
#   -> Requieres jq                         #
#   -> Requieres libnotify-bin              #
# 	 										#
#############################################

# Global variables
HOST='http://localhost:8080'
SITE='20124'
RESOURCE='blog-postings'
AUTHDIGEST="<echo YOUR_USER:YOUR_PWD | base64>"
SYCNPERIOD=30

# Local variables - Keep your dirty hands out of them
API="/o/headless-delivery/v1.0/sites/$SITE/$RESOURCE"
FILTER_NEW='filter=dateCreated gt '
FILTER_MOD='filter=dateModified gt '
SORT='sort=headline:desc,dateCreated:asc'
ICON="$HOME/.liferay/liferay.ico"

#########################
# ----- FUNCTIONS ----- #
# Get timestamp
timestamp() { date --utc +%FT%TZ; }
# Check logo
previous_checks() {
    command -v curl >/dev/null 2>&1 || { echo "CURL is required but it's not installed.  Aborting."; exit 1; }
    command -v jq >/dev/null 2>&1 || { echo "JQ is required but it's not installed.  Aborting."; exit 1; }
    command -v notify-send >/dev/null 2>&1 || { echo "LIBNOTIFY-BIN is required but it's not installed.  Aborting."; exit 1; }
    
    if [ ! -d $(dirname "${ICON}") ]; then
        mkdir -p $(dirname "${ICON}");
    fi
    if [ ! -f "$ICON" ]; then
        echo "Icon not found, let's download it"
        wget -O $ICON "$HOST/o/admin-theme/images/favicon.ico"
    fi
}
# Show Notification
show_notification() {
    if [ ! -z "$1" ]; then
        echo "$1"
        if [ $(echo $1 | jq type 2>/dev/null) == "\"object\"" ]; then
            if [ $(echo "${1}" | tr '\r\n' ' ' | jq '.totalCount') -gt 0 ]; then
                echo $1 | tr '\r\n' ' ' | jq -c '.items[]' | while read -r row; do
                    title=$(echo "${row}" | jq -r .headline)
                    description=$(echo "${row}" | jq -r .alternativeHeadline)
                    body=$(echo "${row}" | jq -r .articleBody | cut -c 1-80)
                    link="$HOST/$(echo "${row}" | jq -r .friendlyUrlPath)"
                    notify-send -i $ICON -a "Liferay DXP" "$2!" "<b>$title</b><br/>$description<br/><a href='$HOST/web/guest/blogs/-/blogs/$link'>More info.</a>"
                done
            fi
        fi
    fi
}


####################
# ----- MAIN ----- #

### CHECKS BEFORE START
echo "Checking dependencies..."
previous_checks
lastcheck=$(timestamp)

### MAIN LOOP
while true; do
    # Check new posts
    echo "Checking changes after $lastcheck"
    RESPONSE=$(curl -G -s -H "Authorization: Basic ${AUTHDIGEST}" --data-urlencode "${FILTER_NEW}${lastcheck}" --data-urlencode "${SORT}" $HOST$API)
    show_notification "$RESPONSE" "POST CREATED" 
    
    # Check updates
    RESPONSE=$(curl -G -s -H "Authorization: Basic ${AUTHDIGEST}" --data-urlencode "${FILTER_MOD}${lastcheck}" --data-urlencode "${SORT}" $HOST$API)
    show_notification "$RESPONSE" "POST UPDATED"
    
    lastcheck=$(timestamp)
    sleep $SYCNPERIOD
done
