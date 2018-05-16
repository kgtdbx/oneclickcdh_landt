#!/bin/bash

LOC=`pwd`
PROPS=$1
CLUSTER_PROPERTIES=$1
source $LOC/$PROPS 2>/dev/null
CM_SERVER=`grep -w HOST[0-9]* $LOC/$CLUSTER_PROPERTIES|head -1|cut -d'=' -f2`.$DOMAIN_NAME

curl -X PUT -H "Content-Type:application/json" -u admin:admin -X PUT --data @$LOC/maxiq_queue.json http://$CM_SERVER:7180/api/v19/clusters/hdptest/services/yarn/config

curl -X POST  -H "Content-Type:application/json" -u admin:admin http://$CM_SERVER:7180/api/v19/clusters/$CLUSTERNAME/commands/stop
echo "Please wait while stopping and starting services"
sleep 60
curl -X POST  -H "Content-Type:application/json" -u admin:admin http://$CM_SERVER:7180/api/v19/clusters/$CLUSTERNAME/commands/start
