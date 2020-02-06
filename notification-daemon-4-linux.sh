#!/bin/sh
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

# Global variables
HOST='http://localhost'
SITE='20124'
AUTH=

# Local variables
API1="/o/headless-delivery/v1.0/sites/$SITE/blog-postings?filter=dateModified gt "
API2='&sort=headline:desc,dateCreated:asc'

#########################
# ----- FUNCTIONS ----- #

# Get timestamp
timestamp() {
  date --utc +%FT%TZ
}

####################
# ----- MAIN ----- #

while true 
do
	API3="$API1$(timestamp)$API2"
	curl  -H "Authorization: Basic $AUTH" "$HOST$API3" 
	sleep 30
done
