#!/bin/bash

#****************************************************************************
#    ddns_update.sh - script to update AWS Route53 record
#    version: 1.0.0
#****************************************************************************

## Variables
APP_NAME='ddns_update.sh'
APP_DATA_PATH='/opt/ddns_update'

IP_INFO_WEB='ipinfo.io'
IP_DATA_FILE=$APP_DATA_PATH/current_ip.dat
CONF_FILE=$APP_DATA_PATH/ddns_update.conf

## Functions
function log() {
    logger -t $APP_NAME -p local0.notice -i $@ 
}

## Main routine

# Sanity check
if !(type jq > /dev/null 2>&1) ||
   !(type http > /dev/null 2>&1) ||
   !(type logger > /dev/null 2>&1) ||
   !(type cli53 > /dev/null 2>&1); then
   echo "Some commands are missing"
   exit 1; 
fi

# Read configuration file
if [ -f $CONF_FILE ]; then
    source $CONF_FILE
fi
if [ -z "$DNS_ZONE" ] ||
   [ -z "$AWS_PROFILE" ] ; then
   log "Some DNS data are missing"
   exit 1
fi

# Get old IP address
if [ -f $IP_DATA_FILE ]; then
    OLD_IP=`cat $IP_DATA_FILE`
else
    OLD_IP='0.0.0.0'
fi

# Get current IP address
CURRENT_IP=`http $IP_INFO_WEB | jq -r '.ip'`
if [ -n "$CURRENT_IP" ]; then
    echo $CURRENT_IP > $IP_DATA_FILE
else
    log "CURRENT IP: FAILED"
    exit 1
fi

# Check if IP is changed
if [ "$OLD_IP" == "$CURRENT_IP" ]; then
    log "CURRENT IP: $CURRENT_IP"
    exit 0
else
    log "IP CHANGED: $OLD_IP to $CURRENT_IP"
fi

# Update Route53
cli53 rrcreate $DNS_ZONE "* A $CURRENT_IP" --replace --profile $AWS_PROFILE
if [ $? == 0 ]; then
    log "UPDATE ROUTE53 RECORD: SUCCESS" 
else
    log "UPDATE ROUTE53 RECORD: FAILED"
fi

