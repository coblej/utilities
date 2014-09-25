#!/bin/sh
##
## Switch to course-assets application directory
##
cd /Users/coblej/Sites/course-assets
##
## Redis Server start-up for course-assets
##
# now run as a service using launchd / launchctl
# redis-server /etc/redis/redis.conf > log/redis.log &
##
## Reque worker start-up for course-assets
##
QUEUE=* rake environment resque:work &
