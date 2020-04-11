# DOBAK - MySQL & filesystem backup tool for Linux servers

## What it is
DOBAK is a simple, self-contained (ie it consists of only one file, an executable BASH script) tool you place on your server to create backups of your data, optionally compressing them and/or uploading them to external services like FTP and Owncloud. You can choose to be notified through email and/or push notifications of the status of your backup jobs.

## History
This script is the evolution of a simple script I wrote many years ago to perform rapid and painless backups of DBs and filesystems across many servers. It's not meant to replace any more featured backup systems, it's a tool for when you need a single, versatile tool to make simple backups of your data.

I like the idea of not installing anything if a simple script can do the job.
In most cases, you don't even need to manually add it to crontab: if your use case is to run backups hourly/daily/weekly/monthly you can just use `dobak -ih`, `-id`, `-iw` or `-im` and it will self-install with the appropriate schedule.

## Installation
To download DOBAK from your shell:
```
curl https://raw.githubusercontent.com/nitefood/dobak/master/dobak.sh > dobak && chmod +x dobak
```
After that, start by running `./dobak --help` for usage instructions.

## Configuration
You configure DOBAK by simply editing it with a text editor and changing values in the **Configuration** section.

## Security considerations
Once configured, this script will hold sensitive informations like your MySQL password and Pushbullet API token. Make sure you download and run this script from a secure location on your server (*/root* would be a good idea. Never **ever** save it to a publicly accessible path like */var/www/\**).

## Supported features
* Self-contained (consists of a single file). No need to install anything or use separate configuration files.
* Schedule and remove backup cron jobs directly by running the tool with the appropriate command line option
* Easy to use: just list MySQL DBs (or just back them all up) and directories to backup and run it
* DB inclusion and exclusion lists
* Separate staging (working) directory to backup network filesystems more painlessly
* Customizable compression level for your tar backups (*none/gzip/bzip2/xz*)
* Configuration check to test your settings before running any backup job
* Configuration dump to quickly copy/paste your settings to multiple servers
* Email notification on warning/error/success
* Push notifications to your mobile phone on warning/error/success using https://www.pushbullet.com/ (free account required)
* External uploading of backup files (configurable for every backup or every *n* days). Currently supported external services: FTP, Owncloud/Nextcloud
* Configurable automatic purging of old backups

## Unsupported features
This script does *not* perform incremental filesystem backups, only full directory backups.

## Usage
```
Usage:
        dobak <command>

Supported commands:

  -r, --run
        Run script manually (immediate backup)

  -c, --check-config
        Perform configuration checks (required programs, compressor, etc) and exit
        (no data is written to disk)

  -ih, --install-hourly
        Install under /etc/cron.hourly (create HOURLY Backup job)

  -id, --install-daily
        Install under /etc/cron.daily (create DAILY Backup job)

  -iw, --install-weekly
        Install under /etc/cron.weekly (create WEEKLY Backup job)

  -im, --install-monthly
        Install under /etc/cron.monthly (create MONTHLY Backup job)

  -u, --uninstall-cronjobs
        Remove all cron jobs (hourly/daily/weekly/monthly) installed using -ih, -id, -iw or -im.
        Note: does not remove dobak from your system.

  -d, --dump-config
        Dump configuration settings for easy copy/paste to another server

  -v, --version
        Print dobak version

  -h, --help
        Display this help
```

## Limitation of Liability
I will not be liable for damages or losses arising from your use of this script. I run this on all my production servers but backups are a delicate matter. Generally make sure you don't leave anything out, double check your actions and configurations, and, as always, do as much testing as you possibly can before deploying to production.

## Feedback
Any feedback is welcome. Write your thoughts to a.provvisiero@bvnetworks.it.
