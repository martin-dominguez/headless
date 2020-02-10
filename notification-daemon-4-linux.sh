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

daemonName="dxp-notification-daemon"

pidDir="."
pidFile="$pidDir/$daemonName.pid"
pidFile="$daemonName.pid"

logDir="."
# To use a dated log file.
# logFile="$logDir/$daemonName-"`date +"%Y-%m-%d"`".log"
# To use a regular log file.
logFile="$logDir/$daemonName.log"

# Log maxsize in KB
logMaxSize=1024   # 1mb

runInterval=30 # In seconds

# Global variables
HOST='http://localhost:8080'
SITE='20124'
RESOURCE='blog-postings'
AUTHDIGEST="bWFydGluLmRvbWluZ3VlekBsaWZlcmF5LmNvbTp0ZXN0Cg=="

# Local variables - Keep your dirty hands out of them
API="/o/headless-delivery/v1.0/sites/$SITE/$RESOURCE"
FILTER_NEW='filter=dateCreated gt '
FILTER_MOD='filter=dateModified gt '
SORT='sort=headline:desc,dateCreated:asc'
ICON="$HOME/.liferay/liferay.ico"

#########################
# ----- FUNCTIONS ----- #

timestamp() { date --utc +%FT%TZ; }

previousChecks() {
  # Check requirements and dependencies
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

showNotification() {
  # Send notification
  if [ ! -z "$1" ]; then
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

doCommands() {
  # Check new posts and updates
  # DEBUG: echo "Checking changes after $lastcheck"
  RESPONSE=$(curl -G -s -H "Authorization: Basic ${AUTHDIGEST}" --data-urlencode "${FILTER_NEW}${lastcheck}" --data-urlencode "${SORT}" $HOST$API)
  showNotification "$RESPONSE" "POST CREATED" 
  
  # Check updates
  RESPONSE=$(curl -G -s -H "Authorization: Basic ${AUTHDIGEST}" --data-urlencode "${FILTER_MOD}${lastcheck}" --data-urlencode "${SORT}" $HOST$API)
  showNotification "$RESPONSE" "POST UPDATED"

  lastcheck=$(timestamp)
}

myPid=`echo $$`

setupDaemon() {
  # Make sure that the directories work and dependencies are installed.
  previousChecks
  
  if [ ! -d "$pidDir" ]; then
    mkdir "$pidDir"
  fi
  if [ ! -d "$logDir" ]; then
    mkdir "$logDir"
  fi
  if [ ! -f "$logFile" ]; then
    touch "$logFile"
  else
    # Check to see if we need to rotate the logs.
    size=$((`ls -l "$logFile" | cut -d " " -f 5`/1024))
    if [[ $size -gt $logMaxSize ]]; then
      mv $logFile "$logFile.old"
      touch "$logFile"
    fi
  fi
}

startDaemon() {
  # Start the daemon.
  setupDaemon # Make sure the directories are there.
  lastcheck=$(timestamp) # Set current date as starting date
    
  checkDaemon > /dev/null 2>&1
  if [[ "$?" -eq 1 ]]; then
    echo -e " * \e[31mError\033[39m: $daemonName is already running."
    exit 1
  fi
  echo " * Starting $daemonName with PID: $myPid."
  echo "$myPid" > "$pidFile"
  log '*** '`date +"%Y-%m-%d"`": Starting up $daemonName."

  # Start the loop.
  loop
}

stopDaemon() {
  # Stop the daemon.  
  checkDaemon > /dev/null 2>&1
  if [[ "$?" -eq 0 ]]; then
    echo -e " * \033[31;5;148mError\033[39m: $daemonName is not running."
    exit 1
  fi
  echo " * Stopping $daemonName"
  log '*** '`date +"%Y-%m-%d"`": $daemonName stopped."

  if [[ ! -z `cat $pidFile` ]]; then
    kill -9 `cat "$pidFile"` &> /dev/null
  fi
}

statusDaemon() {
  # Query and return whether the daemon is running.
  checkDaemon > /dev/null 2>&1
  if [[ "$?" -eq 1 ]]; then
    echo " * $daemonName is running."
  else
    echo " * $daemonName isn't running."
  fi
  exit 0
}

restartDaemon() {
  # Restart the daemon.
  checkDaemon > /dev/null 2>&1
  if [[  "$?" = 0 ]]; then
    # Can't restart it if it isn't running.
    echo "$daemonName isn't running."
    exit 1
  fi
  stopDaemon
  startDaemon
}

checkDaemon() {
  # Check to see if the daemon is running.
  if [ -z "$oldPid" ]; then
    return 0
  elif [[ `ps aux | grep "$oldPid" | grep -v grep` > /dev/null ]]; then
    if [ -f "$pidFile" ]; then
      if [[ `cat "$pidFile"` == "$oldPid" ]]; then
        # Daemon is running.
        return 1
      else
        # Daemon isn't running.
        return 0
      fi
    fi
  elif [[ `ps aux | grep "$daemonName" | grep -v grep | grep -v "$myPid" | grep -v "0:00.00"` > /dev/null ]]; then
    # Daemon is running but without the correct PID. Restart it.
    log '*** '`date +"%Y-%m-%d"`": $daemonName running with invalid PID; restarting."
    restartDaemon
    return 1
  else
    # Daemon not running.
    return 0
  fi
  return 1
}

loop() {
  # This is the loop.
  now=`date +%s`

  if [ -z $last ]; then
    last=`date +%s`
  fi

  doCommands

  # Check to see how long we actually need to sleep for. If we want this to run
  # once a minute and it's taken more than a minute, then we should just run it
  # anyway.
  last=`date +%s`

  # Set the sleep interval
  if [[ ! $((now-last+runInterval+1)) -lt $((runInterval)) ]]; then
    sleep $((now-last+runInterval))
  fi

  # Startover
  loop
}

log() {
  # Generic log function.
  echo "$1" >> "$logFile"
}


################################################################################
# Parse the command.
################################################################################

if [ -f "$pidFile" ]; then
  oldPid=`cat "$pidFile"`
fi
checkDaemon
case "$1" in
  start)
    startDaemon
    ;;
  stop)
    stopDaemon
    ;;
  status)
    statusDaemon
    ;;
  restart)
    restartDaemon
    ;;
  *)
  echo -e "\033[31;5;148mError\033[39m: usage $0 { start | stop | restart | status }"
  exit 1
esac

exit 0
