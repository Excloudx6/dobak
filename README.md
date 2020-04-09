# DOBAK
Simple, self-contained MySQL DB &amp; filesystem backup tool with email/push notification support and FTP/Owncloud upload support

## What it is
DOBAK is a self-contained (ie it consists of only one file, an executable BASH script) tool you place on your server, and it creates backups of your data, optionally compressing them and/or uploading them to external services like FTP and Owncloud.

## Why
This script is the evolution of a simple script I wrote many years ago to perform rapid and painless backups of DBs and filesystems across many servers. It's not meant to replace any more featured backup systems, it's a tool for when you need a single, versatile tool to make simple backups of your data.

I like the idea of not installing anything if a simple script can do the job.
In most cases, you don't even need to manually add it to crontab: if your use case is to run backups hourly/daily/weekly/monthly you can just use `dobak -ih`, `-id`, `-iw` or `-im` and it will self-install with the appropriate schedule.

## Installation
To download DOBAK from your shell:
```
# curl https://raw.githubusercontent.com/nitefood/dobak/master/dobak.sh > dobak && chmod +x dobak
```
After that, start by running `./dobak --help` for usage instructions.

## Configuration
You configure DOBAK by simply editing it with a text editor and changing values in the `Configuration` section.

## Supported features
* Self-contained (consists of a single file). No need to install anything or use separate configuration files.
* Schedule and remove backup cron jobs directly by running the tool with the appropriate command line option
* Easy to use: just list MySQL DBs (or just back them all up) and directories to backup and run it
* Separate staging (working) directory to backup network filesystems more painlessly
* Customizable compression for your tar backups (none/gzip/bzip2/xz)
* Email notification on warning/error/success
* Push notifications to your mobile phone on warning/error/success using https://www.pushbullet.com/ (free account required)
* External uploading of backup files (configurable for every backup or every N days). Currently supported external services: FTP, Owncloud/Nextcloud
* Configurable automatic purging of old backups

## Unsupported features
This script does not perform incremental filesystem backups, only full directory backups.

## Limitation of Liability
I will not be liable for damages or losses arising from your use of this script. I run this on all my production servers but backups are a delicate matter. Generally make sure you don't leave anything out, double check your actions and configurations, and, as always, do as much testing as you possibly can before deploying to production.

## Feedback
Any feedback is welcome. Write your thoughts to a.provvisiero@bvnetworks.it.
