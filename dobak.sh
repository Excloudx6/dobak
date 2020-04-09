#!/bin/bash
#
# DOBAK - Simple, self-contained Mysql DB & filesystem backup tool
# with email/push notification support and FTP/Owncloud upload support
# Adriano Provvisiero - BV Networks 2002-2020
#
version='1.0'
rlsdate='2020-04-09'

########################################################################
#
# --- Configuration options ---
#

# - Compression level for backups
#   Supported values:
#     0 = none (no compression)
#     1 = gzip
#     2 = bzip2
#     3 = xz
COMPRESSION_LEVEL=1

# - Destination backup directory
BACKUP_DESTINATION_DIR='/var/backup'

# - Staging directory: backups will be created and compressed here and moved to BACKUP_DESTINATION_DIR only on completion
#	(useful when BACKUP_DESTINATION_DIR is a NFS share or network filesystem)
#	Note: if empty, BACKUP_DESTINATION_DIR will be used.
STAGING_DIR=''

# - Log settings
LOG_ENABLED=true
LOG_COLORS=true
LOGFILE="$BACKUP_DESTINATION_DIR/dobak.log"

# - Mysql credentials
MYSQL_USER='root'
MYSQL_PASSWORD=''

# - Names of MySQL DBs to backup, one per line. Supports spaced names and # comments.
#   Note: if BACKUP_ALL_DATABASES is set to 'true', DBS_TO_BACKUP is ignored.
BACKUP_ALL_DATABASES=false
DBS_TO_BACKUP="
dbexample1
dbexample2
"

# - Directories to backup (recursively), one per line. Supports spaced paths and # comments
DIRS_TO_BACKUP="
/var/www
/etc
/example/spaced path
"

# - How many days to keep old backups (0 = never remove old backups)
#   Note: this applies only to local backups, not external
#   upload sites (e.g. FTP, Owncloud)
DAYS_TO_KEEP_BACKUPS=30

# - Receive an email on backup job warning/error?
#	Possible values:
# 	0 = email notifications DISABLED
# 	1 = email only on job warnings/errors
# 	2 = email on job success/warning/errors
EMAIL_NOTIFICATIONS=0
EMAIL_FROM="dobak@$(hostname -f)"
EMAIL_TO='you@domain.com'

# - Receive a push notification on backup job success/warning/error?
#	Note: requires a Pushbullet account (free on pushbullet.com) 
#	and API token (Settings->Account->Create Access Token)
#	Possible values:
# 	0 = push notifications DISABLED
# 	1 = push only on job warnings/errors
# 	2 = push on job success/warning/errors
PUSHBULLET_NOTIFICATIONS=0
PUSHBULLET_API_TOKEN=''

# - FTP upload options
#   Note: if FTP_PORT is empty, it will use port 21 by default.
#	Note: if FTP_UPLOAD_INTERVAL_DAYS is set to '0' dobak will 
#	upload every backup to your FTP server
FTP_UPLOAD_ENABLE=false
FTP_UPLOAD_INTERVAL_DAYS=30
FTP_HOST=''
FTP_PORT=''
FTP_UPLOAD_REMOTE_PATH=''
FTP_USER='anonymous'
FTP_PASS='password'
FTP_USE_SSL=false
FTP_IGNORE_SSL_WARNINGS=false

# - OWNCLOUD upload options
#	Note: if OWNCLOUD_UPLOAD_INTERVAL_DAYS is set to '0' dobak 
#	will upload every backup to your Owncloud server
OWNCLOUD_UPLOAD_ENABLE=false
OWNCLOUD_UPLOAD_INTERVAL_DAYS=30
OWNCLOUD_HOST='https://example.com/owncloud'
OWNCLOUD_UPLOAD_REMOTE_PATH='Backups'
OWNCLOUD_USER=''
OWNCLOUD_PASS=''
OWNCLOUD_IGNORE_SSL_WARNINGS=false

# - Keep track of FTP/Owncloud uploads here
TRACKFILE="$HOME/.dobak_trackfile"

# You MUST comment out the next line to make backup run!
UNCONFIGURED=true

#
# --- End Configuration - No need to change anything below this line ---
#
########################################################################

# Terminal color codes
if [ $LOG_COLORS = true ]; then
	green="\e[32m"
	yellow="\e[33m"
	white="\e[97m"
	blue="\e[94m"
	red="\e[31m"
	default="\e[39m\e[49m"
else
	green=""
	yellow=""
	white=""
	blue=""
	red=""
	default=""
fi

# Globals
BANNER="${green}DO${white}B${red}AK${default} - ${green}Dirty${default} ${white}Old ${red}Backup${default}${default} v$version ($rlsdate) by Adriano Provvisiero - BV Networks 2002-$(echo "$rlsdate" | cut -d - -f 1)\n"
SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )/$(basename "$0")"
BOOL_WARNING=false
BOOL_ERROR=false
LOG=""

# Helper functions
clean_exit(){
	tput sgr0
	exit $1
}

logme(){
	if [ ! $LOG_ENABLED = true ]; then
	LOGFILE="/dev/null"
	fi
	if [ "$1" = "-n" ]; then
	LOG+="$2"
	echo -n -e "$2" | tee -a "$LOGFILE"
	else
	LOG+="$1\n"
	echo -e "$1" | tee -a "$LOGFILE"
	fi
}

print_help(){
	echo -e "\n$BANNER\n${white}Simple, self-contained MySQL DB & filesystem backup tool with Email/Pushbullet notifications and FTP/Owncloud upload support.${default}\
		\n\n\nUsage:\n\t${white}dobak <command>${default}\n\nSupported commands:\n\
		\n  ${white}-r, --run\n\t${default}Run script manually (immediate backup)\n\
	\n  ${white}-c, --check-config\n\t${default}Perform configuration checks (required programs, compressor, etc) and exit (no data is written to disk)\n\
	\n  ${white}-ih, --install-hourly\n\t${default}Install under ${yellow}/etc/cron.hourly${default} (create HOURLY Backup job)\n\
		\n  ${white}-id, --install-daily\n\t${default}Install under ${yellow}/etc/cron.daily${default} (create DAILY Backup job)\n\
		\n  ${white}-iw, --install-weekly\n\t${default}Install under ${yellow}/etc/cron.weekly${default} (create WEEKLY Backup job)\n\
		\n  ${white}-im, --install-monthly\n\t${default}Install under ${yellow}/etc/cron.monthly${default} (create MONTHLY Backup job)\n\
		\n  ${white}-u, --uninstall-cronjobs\n\t${default}Remove all cron jobs (hourly/daily/weekly/monthly) installed using -ih, -id, -iw or -im.\n\t${white}Note${default}: does not remove dobak from your system.\n\
		\n  ${white}-d, --dump-config\n\t${default}Dump configuration settings for easy copy/paste to another server\n\
		\n  ${white}-v, --version\n\t${default}Print dobak version\n\
		\n  ${white}-h, --help\n\t${default}Display this help\n\
	\n\n\n${yellow}Note: ${white}before you can use this script, you must set its configuration parameters (backup paths, options, passwords etc). Start by editing ${yellow}${SCRIPTPATH}${default}.\
	\n\nPlease report any feedback to ${blue}a.provvisiero@bvnetworks.it${default}.\n"
	clean_exit 0
}

dump_config(){
	clear
	echo -e "${green}DOBAK v$version ($rlsdate) configuration values${default}:\n\n[Script path: ${white}$SCRIPTPATH${default}]\n${white}"
	config_marker="########################################################################"
	sed -n "/^$config_marker/,/^$config_marker/p" "$SCRIPTPATH"
	echo -e "${default}"
	clean_exit 0
}

install_me(){
	DEST="${1}/dobak"
	echo -n -e "\n$BANNER\n${white}Installing cron job to ${yellow}${DEST}${white} ... "
	touch "$DEST" 2>/dev/null
	if [[ $? -eq 1 ]]; then
		echo -e "${red}ERROR! ${default}Make sure you are running dobak as root\n"
	else
		echo -e "#!/bin/sh\n\n$SCRIPTPATH --run\n\nclean_exit 0\n" > "$DEST"
		chmod +x "$DEST"
		echo -e "${green}OK\n\n${white}Important: ${default}the cron job will still invoke ${green}$SCRIPTPATH${default} (this file), \nwhere ${white}all your configuration is stored${default}. So keep it in its place!\n"
	fi
	clean_exit 0
}

uninstall(){
	echo -n -e "${white}Uninstalling all ${yellow}/etc/cron.{hourly,daily,weekly,monthly}/dobak${white} cron jobs ... "
	rm -f /etc/cron.hourly/dobak /etc/cron.daily/dobak /etc/cron.weekly/dobak /etc/cron.monthly/dobak 2>/dev/null
	if [[ $? -eq 1 ]]; then
		echo -e "${red}ERROR! ${default}Make sure you are running dobak as root\n"
	clean_exit 1
	else
		echo -e "${green}OK${default}\n"
	fi
}

ctrl_c(){
	logme -n "\n\n${default}CTRL+C pressed, cleaning up ... "
	rm -rf "${STAGING_DIR}" "${backup_tarfile}" 2>/dev/null
	logme "${green}OK${default}\n\n${red}Backup ABORTED!${default}\n______________________________________________________________\n\n"
	clean_exit 1
}

notify_user(){
	if [ $EMAIL_NOTIFICATIONS -eq 2 ] ||
	  ([ $EMAIL_NOTIFICATIONS -eq 1 ] && ([ $BOOL_WARNING = true ] || [ $BOOL_ERROR = true ])); then
	LOG=$(echo "$LOG" | sed -e 's/\\e\[32m/<b><font color="green">/g' \
			  -e 's/\\e\[33m/<b><font color="DarkGoldenRod">/g' \
			  -e 's/\\e\[97m/<b><font color="steelblue">/g' \
			  -e 's/\\e\[94m/<b><font color="blue">/g' \
			  -e 's/\\e\[31m/<b><font color="red">/g' \
			  -e 's/\\e\[39m\\e\[49m/<\/b><font color="white">/g'
	)
	html_report="<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\" \"http://www.w3.org/TR/html4/loose.dtd\">\n<html>\n<head><style> \
		</style>\n</head>\n<body style=\"background-color:black;\">\n<pre><span class=\"inner-pre\" style=\"display: block; font-family: monospace; white-space: pre; margin: 1em 0;\"><font color=\"white\" /><h2>DOBAK backup job log output:</h2>$LOG</span></pre>\n</body>\n</html>"
	echo -e "$html_report" | mail -s "$1" -a "MIME-Version: 1.0" -a "Content-Type: text/html" -a "From: $EMAIL_FROM" $EMAIL_TO
	fi
	if [ $PUSHBULLET_NOTIFICATIONS -eq 2 ] ||
	  ([ $PUSHBULLET_NOTIFICATIONS -eq 1 ] && ([ $BOOL_WARNING = true ] || [ $BOOL_ERROR = true ])); then
	if [ $BOOL_WARNING = true ]; then
		title="[$(hostname)] Backup job WARNING"
		body="DOBAK backup job on $(hostname) completed with WARNINGS. Inspect the log file for details"
	elif [ $BOOL_ERROR = true ]; then
		title="[$(hostname)] Backup job FAILED"
		body="DOBAK backup job on $(hostname) FAILED. Inspect the log file at [${LOGFILE}] for details"
	else
		title="[$(hostname)] Backup job SUCCESSFUL"
		body="DOBAK backup job on $(hostname) completed succesfully."
	fi
	curl -s --header "Access-Token: ${PUSHBULLET_API_TOKEN}" \
	 --header 'Content-Type: application/json' \
	 --data-binary "{\"body\":\"$body\",\"title\":\"$title\",\"type\":\"note\"}" \
	 --request POST \
	 https://api.pushbullet.com/v2/pushes > /dev/null
	fi
}

datediff() { # cheers https://unix.stackexchange.com/a/24636
	d1=$(date -d "$1" +%s)
	d2=$(date -d "$2" +%s)
	echo $(( (d1 - d2) / 86400 ))
}

check_last_upload_date() {
	# check if trackfile present
	if [ ! -f "$TRACKFILE" ]; then
		return 1
	fi
	interval="$1_UPLOAD_INTERVAL_DAYS" # e.g. "FTP_UPLOAD_INTERVAL_DAYS"
	interval=${!interval}
	if [[ "$interval" -gt 0 ]]; then
		# read last upload date from trackfile
		last_upload="$(cat "$TRACKFILE" | grep "$1" | cut -d '=' -f 2 | tr -d ' ')"
		if [ -z $last_upload ]; then
	# we never uploaded to this service, proceed
	return 1
		fi
		days_since_last_upload=$(datediff $(date +"%Y-%m-%d") $last_upload)
		if [[ "$days_since_last_upload" -lt "$1"_UPLOAD_INTERVAL_DAYS ]]; then
	return 0
		fi
	fi
	return 1
}

update_trackfile() {
	if [ -f "$TRACKFILE" ]; then
		trackfile_contents=$(grep -v "$1" "$TRACKFILE")
	else
		trackfile_contents=""
	fi
	trackfile_contents="${trackfile_contents}\n$1=$(date +"%Y-%m-%d")"
	echo -e "$trackfile_contents" | grep -v "^$" > "$TRACKFILE" 2>/dev/null
}

ftp_upload(){
	if [ $FTP_UPLOAD_ENABLE = true ]; then
	logme -n "\n${default}FTP Uploading to '${white}ftp://$FTP_HOST${default}' ... "
	check_last_upload_date "FTP"
	if [ $? = 0 ]; then
		logme "${yellow}SKIPPED (last uploaded $days_since_last_upload days ago)${default}"
		return
	fi
	if [ $FTP_USE_SSL = true ]; then
		ssl_switch="--ftp-ssl"
	else
		ssl_switch=""
	fi
	if [ $FTP_IGNORE_SSL_WARNINGS = true ]; then
		insecure_switch="--insecure"
	else
		insecure_switch=""
	fi
	if [ "$FTP_PORT" = "" ]; then
		FTP_PORT="21"
	fi
	FTP_UPLOAD_REMOTE_PATH=$(echo "$FTP_UPLOAD_REMOTE_PATH" | sed 's/ /%20/g')
	result=$((curl $insecure_switch $ssl_switch -sS --ftp-create-dirs -T "$backup_tarfile" ftp://"$FTP_USER":"$FTP_PASS"@"$FTP_HOST":"$FTP_PORT"/"$FTP_UPLOAD_REMOTE_PATH/") 2>&1)
	if [ -n "$result" ]; then
		logme "${red}ERROR: $result${default}"
		BOOL_WARNING=true
	else
		# upload OK, update trackfile
		update_trackfile "FTP"
		logme "${green}OK${default}"
	fi
	fi
}

owncloud_upload(){
	if [ $OWNCLOUD_UPLOAD_ENABLE = true ]; then
	logme -n "\n${default}OWNCLOUD Uploading to '${white}$OWNCLOUD_HOST${default}' ... "
	check_last_upload_date "OWNCLOUD"
	if [ $? = 0 ]; then
		logme "${yellow}SKIPPED (last uploaded $days_since_last_upload days ago)${default}"
		return
	fi
	if [ $OWNCLOUD_IGNORE_SSL_WARNINGS = true ]; then
		insecure_switch="--insecure"
	else
		insecure_switch=""
	fi
	OWNCLOUD_UPLOAD_REMOTE_PATH=$(echo "$OWNCLOUD_UPLOAD_REMOTE_PATH" | sed 's/ /%20/g')
	upload_filename=$(echo "$upload_filename" | sed 's/ /%20/g')
	curl $insecure_switch -sS -u "$OWNCLOUD_USER:$OWNCLOUD_PASS" -X MKCOL "$OWNCLOUD_HOST/remote.php/dav/files/$OWNCLOUD_USER/$OWNCLOUD_UPLOAD_REMOTE_PATH" &>/dev/null
	curl $insecure_switch -sS -u "$OWNCLOUD_USER:$OWNCLOUD_PASS" -T "$backup_tarfile" "$OWNCLOUD_HOST/remote.php/dav/files/$OWNCLOUD_USER/$OWNCLOUD_UPLOAD_REMOTE_PATH/$upload_filename" &>/dev/null
	# after upload, check if file exists on server
	result_oc_propfind=$(curl $insecure_switch -sS -u "$OWNCLOUD_USER:$OWNCLOUD_PASS" \
		-X PROPFIND "$OWNCLOUD_HOST/remote.php/dav/files/$OWNCLOUD_USER/$OWNCLOUD_UPLOAD_REMOTE_PATH/$upload_filename" \
		| grep '<d:status>HTTP/1.1 200 OK</d:status>')
	if [ -z "$result_oc_propfind" ]; then
		logme "${red}ERROR: Upload failed. Check your Owncloud server logs for more info${default}"
		BOOL_WARNING=true
	else
		# upload OK, update trackfile
		update_trackfile "OWNCLOUD"
		logme "${green}OK${default}"
	fi
	fi
}

sanity_check(){
	# check if configured
	if [ ! -z "$UNCONFIGURED" ]; then
		echo -e "\n\t\t${yellow}!!! WARNING !!!${white}\n\nYou must first configure backup parameters.\nEverything is in the configuration block\ninside ${yellow}${SCRIPTPATH}${white} (this file).${default}\n"
		clean_exit 1
	fi

	# check for chosen compressor software presence
	case "$COMPRESSION_LEVEL" in
		"0")
			compression="No compression"
			compressor_tool="none"
			tar_compression_flag=""
			tar_extension=""
			;;
		"1")
			compression="GZIP"
			compressor_tool="gzip"
			tar_compression_flag="z"
			tar_extension=".gz"
			;;
		"2")
			compression="BZIP2"
			compressor_tool="bzip2"
			tar_compression_flag="j"
			tar_extension=".bz2"
			;;
		"3")
			compression="XZ"
			compressor_tool="xz"
			tar_compression_flag="J"
			tar_extension=".xz"
			;;
		*)
			echo -e "\n${red}ERROR: unknown compression level '$COMPRESSION_LEVEL'.\n\n${default}Please choose a supported compression by editing ${white}${SCRIPTPATH}${default}\n"
			clean_exit 1
			;;
	esac
	if [ -z $(command -v $compressor_tool) ] && [ ! $COMPRESSION_LEVEL = "0" ]; then
		echo -e "\n${red}ERROR: ${default}program '${white}$compressor_tool${default}' not found on this system.\nPlease install it or choose another compression level by editing ${white}${SCRIPTPATH}${default}\n"
		clean_exit 1
	fi
	
	# helper tools check
	if [ $FTP_UPLOAD_ENABLE = true ] || [ $OWNCLOUD_UPLOAD_ENABLE = true ] || [ $PUSHBULLET_NOTIFICATIONS -gt 0 ]; then
		if [ -z $(command -v "curl") ]; then
	echo -e "\n${red}ERROR: ${default}program '${white}curl${default}' not found on this system. It is required to use FTP/Owncloud upload\nand to send PUSH notifications using Pushbullet.\nPlease install it (for example with ${green}sudo apt install curl${default} on Debian-based linux distributions)\nor adjust your configuration by editing ${white}${SCRIPTPATH}${default}\n"
	clean_exit 1
		fi
	fi
	if [ $EMAIL_NOTIFICATIONS -gt 0 ]; then
		if [ -z $(command -v "mail") ]; then
	echo -e "\n${red}ERROR: ${default}program '${white}mail${default}' not found on this system. It is required to send EMAIL notifications.\nPlease install it (for example with ${green}sudo apt install mailutils${default} on Debian-based linux distributions)\nor adjust your configuration by editing ${white}${SCRIPTPATH}${default}\n"
	clean_exit 1
		fi
	fi
	if [ -z  "$PUSHBULLET_API_TOKEN" ] && [ $PUSHBULLET_NOTIFICATIONS -gt 0 ]; then
	echo -e "\n${red}ERROR: ${default}you need to specify a valid Pushbullet API Token to enable push notifications.\nVisit ${blue}https://www.pushbullet.com/${default} and sign up for a free account, then\ncreate a token by going to ${white}Settings${default} -> ${white}Account${default} -> ${white}Create Access Token${default}.\n"
	clean_exit 1
	fi
}

run_backup(){
	curdate=$(date +%F_%H.%M)
	DBLIST=$(echo -e "$DBS_TO_BACKUP" | grep -v "^#" | tr -s '\n')
	DIRLIST=$(echo -e "$DIRS_TO_BACKUP" | grep -v "^#" | tr -s '\n')
	IFS=$'\n'
	for db in $(echo "$dbs"); do echo "will backup $db"; done
	
	if [ "$STAGING_DIR" = "" ]; then
		STAGING_DIR="$BACKUP_DESTINATION_DIR"
	fi
	STAGING_DIR="${STAGING_DIR}/$(hostname)_backup@$curdate"
	backup_tarfile="$(echo ${BACKUP_DESTINATION_DIR}/$(hostname)_backup@$curdate | sed 's/\/$//').tar"

	# check if we can write to logfile and destination/staging dirs
	result=$((mkdir -p $(dirname "$LOGFILE") 2>&1) && (touch "$LOGFILE") 2>&1)
	if [[ $? -eq 1 ]]; then
	echo -e "\n${red}ERROR: ${white}Could not write to logfile ${default}($result)\n${white}Proceeding without a logfile, only stdout${default}\n"
	BOOL_WARNING=true
	LOG_ENABLED=false
	fi
	result=$((mkdir -p "$BACKUP_DESTINATION_DIR") 2>&1)
	if [[ $? -eq 1 ]]; then
		logme "${red}ERROR: ${white}Could not write to destination directory ${default}($result)\n"
		logme "${red}Backup ABORTED!${default}\n______________________________________________________________\n\n"
		notify_user "Backup job on $(hostname) FAILED"
	    clean_exit 1
		BOOL_ERROR=true
	fi
	result=$((mkdir -p "$STAGING_DIR") 2>&1)
	if [[ $? -eq 1 ]]; then
		logme "${red}ERROR: ${white}Could not write to staging directory ${default}($result)\n"
		logme "${red}Backup ABORTED!${default}\n______________________________________________________________\n\n"
		notify_user "Backup job on $(hostname) FAILED"
	    clean_exit 1
	fi

	# START Backup job
	starttime=$(date +"%s")
	clear
	logme -n "______________________________________________________________\n\n${yellow}BACKUP JOB STARTED AT\t${white} "
	logme "$(date +'%F %H:%M')"
	logme "${default}\nBackup filename:\n\t${white}${backup_tarfile}${default}"
	logme "${default}\nStaging directory:\n\t${white}$(dirname ${STAGING_DIR})${default}\n\nDBs to backup:"
	for db in $(echo "$DBLIST"); do logme "\t${white}$db${default}"; done
	logme "\nDirectories to backup:"
	for dir in $(echo "$DIRLIST"); do logme "\t${white}$dir${default}"; done
	logme "\nCompression:\n\t${white}$compression${default}\n\n"

	# trap ctrl-c and call ctrl_c()
	trap ctrl_c INT

	mkdir -p "${STAGING_DIR}/db" "${STAGING_DIR}/filesystem"

	chmod 700 "$STAGING_DIR"

	if [ $BACKUP_ALL_DATABASES = true ]; then
		logme -n "Backing up MySQL DB :\t[${white}ALL DATABASES${default}] ... "
		DESTDBFILE="${STAGING_DIR}/db/all_databases.sql"
		result=$((mysqldump --single-transaction --all-databases --user="$MYSQL_USER" --password="$MYSQL_PASSWORD" >> "${DESTDBFILE}") 2>&1 | grep -v "Using a password")
		if [ -n "$result" ]; then
			logme "${red}ERROR: $result${default}"
			BOOL_WARNING=true
			rm -f "${DESTDBFILE}"
			continue
		fi
		[ "$compression" = "none" ] || $compressor_tool "${DESTDBFILE}" &&\
		logme "${green}OK${default}"
	else
		for db in $(echo "$DBLIST")
		do
			logme -n "Backing up MySQL DB :\t[${white}${db}${default}] ... "
			DESTDBFILE="${STAGING_DIR}/db/${db}.sql"
			echo -e "CREATE DATABASE \`${db}\`;\nUSE \`${db}\`;\n\n" > "${DESTDBFILE}" &&\
				 result=$((mysqldump --single-transaction "${db}" --user="$MYSQL_USER" --password="$MYSQL_PASSWORD" >> "${DESTDBFILE}") 2>&1 | grep -v "Using a password")
				 if [ -n "$result" ]; then
				logme "${red}ERROR: $result${default}"
				BOOL_WARNING=true
				rm -f "${DESTDBFILE}"
				continue
				 fi
				 [ "$compression" = "none" ] || $compressor_tool "${DESTDBFILE}" &&\
				 logme "${green}OK${default}"
		done
	fi
		
	for dir in $(echo "$DIRLIST")
	do
		logme -n "Backing up directory:\t'${white}${dir}${default}' ... "
		test -e "${dir}"
		if [[ $? -eq 1 ]]; then
			logme "${red}ERROR: Directory not found/not accessible!${default}"
			BOOL_WARNING=true
		else
			dirname_stripped=$(echo "$dir" | sed -e 's/^\///' -e 's/\/$//')
			dirname_underscores=$(echo "$dirname_stripped" | sed 's/\//_/g')
			tarname="$STAGING_DIR/filesystem/$dirname_underscores.tar${tar_extension}"
			tar -c${tar_compression_flag}pf "${tarname}" -C / "${dirname_stripped}" 2> >(grep -v 'socket ignored' >&2)
			logme "${green}OK${default}"
		fi
	done

	logme -n "\nCreating final backup tar file ... "
	result=$(logme -n $(tar cf "${backup_tarfile}" -C "${STAGING_DIR}/../" $(basename "${STAGING_DIR}") 2>&1))
	if [[ $? -eq 1 ]]; then
		logme "\n${red}ERROR: ${white}Could not write to backup destination directory: ${default}$result\n"
		logme "\n${red}Backup ABORTED!${default}\n______________________________________________________________\n\n"
		BOOL_ERROR=true
		notify_user "[$(hostname)] Backup job FAILED"
		clean_exit 1
	fi
	logme "${green}OK${default}"

	if [ $DAYS_TO_KEEP_BACKUPS -gt 0 ]; then
		logme -n "Removing backups older than ${white}$DAYS_TO_KEEP_BACKUPS days${default} ... "
		find "${BACKUP_DESTINATION_DIR}" -mtime +$DAYS_TO_KEEP_BACKUPS -exec rm -rf {} \; &>/dev/null
		logme "${green}OK${default}"
	fi

	logme -n "Cleaning up ... "
	logme -n $(rm -rf $STAGING_DIR 2>&1)
	logme "${green}OK${default}"

	ftp_upload
	owncloud_upload

	endtime=$(date +"%s")
	logme "\n${yellow}BACKUP JOB FINISHED AT\t${white}$(date +"%F %H:%M") (in $(( endtime - starttime )) seconds)"
	logme -n "${yellow}BACKUP SIZE\t\t${white}$(du -h "${backup_tarfile}" | cut -f1) "
	warnmsg=""
	if [ "$BOOL_WARNING" = true ]; then
		warnmsg=" ${yellow}WITH WARNINGS"
		notify_user "[$(hostname)] Backup job was completed with WARNINGS"
	else
		notify_user "[$(hostname)] Backup job SUCCESSFUL"
	fi
	logme "\n\n${green}All done$warnmsg${default}\n______________________________________________________________\n\n"
	
	
}

# End helper functions

case "$1" in
	"-h"|"--help")
		print_help
		;;
	"-ih"|"--install-hourly")
		sanity_check
		install_me "/etc/cron.hourly"
		;;
	"-id"|"--install-daily")
		sanity_check
		install_me "/etc/cron.daily"
		;;
	"-iw"|"--install-weekly")
		sanity_check
		install_me "/etc/cron.weekly"
		;;
	"-im"|"--install-monthly")
		sanity_check
		install_me "/etc/cron.monthly"
		;;
	"-d"|"--dump-config")
		dump_config
		;;
	"-v"|"--version")
		echo -e -n "$BANNER"
		;;
	"-c"|"--check-config")
	clear
		echo -e "$BANNER\n${white}# Configuration check started #"
	sanity_check
	echo -e "\n${green}All checks completed successfully!\n"
		;;
	"-u"|"--uninstall-cronjobs")
	echo -e "\n$BANNER"
		uninstall
		;;
	"-r"|"--run")
	sanity_check
		run_backup
		;;
	*)
		echo -e "\n$BANNER\n${red}ERROR: unknown command\n\n${default}For usage run ${white}$(basename ${0}) --help${default}\n"
	clean_exit 1
		;;
esac

tput sgr0
clean_exit 0
