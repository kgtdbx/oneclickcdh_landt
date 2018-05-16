#!/bin/bash

LOC=`pwd`
PROPS=$1
CLUSTER_PROPERTIES=$1
source $LOC/$PROPS 2>/dev/null
CM_AGENTS=`grep -w HOST[0-9]* $LOC/$CLUSTER_PROPERTIES|cut -d'=' -f2`
CM_SERVER=`grep -w HOST[0-9]* $LOC/$CLUSTER_PROPERTIES|head -1|cut -d'=' -f2`.$DOMAIN_NAME
NUM_OF_HOSTS=`grep HOST $LOC/$PROPS|grep -v SERVICES|wc -l`
LAST_HOST=`grep HOST $LOC/$PROPS|grep -v SERVICES|head -n $NUM_OF_HOSTS|tail -1|cut -d'=' -f2`
grep HOST $LOC/$PROPS|grep -v SERVICES|grep -v $LAST_HOST|cut -d'=' -f2 > $LOC/list
OS_VERSION=`echo $OS|rev|cut -c1|rev`
START_HST_NAME=`grep 'HOST[0-9]*' $LOC/$PROPS|grep -v SERVICES|head -1|cut -d'=' -f1` 2>/dev/null
LAST_HST_NAME=`grep 'HOST[0-9]*' $LOC/$PROPS|grep -v SERVICES|tail -1|cut -d'=' -f1` 2>/dev/null
PASSWORD=`grep -w SSH_SERVER_PASSWORD $LOC/$CLUSTER_PROPERTIES|cut -d'=' -f2`
PVT_KEY=`grep -w SSH_SERVER_PRIVATE_KEY $LOC/$CLUSTER_PROPERTIES|cut -d'=' -f2`
wget='wget --user $REPO_SERVER_WGET_USER --password $REPO_SERVER_WGET_PASS'
out_file=cdh

num_of_hosts=`grep HOST $LOC/$PROPS|grep -v SERVICES|wc -l`


#+++++++++++++++++++++++
# Usage Function
if [ $# -ne 1 ]
then
        printf "Usage $0 /path-to/cluster.props\nExample: $0 /opt/single_multinode_autodeploy/<cluster props File> \n"
        exit
fi
#+++++++++++++++++++++++

#Function to print timestamp
timestamp()
{
echo -e  "\033[36m`date +%Y-%m-%d-%H:%M:%S`\033[0m"
}




#+++++++++++++++++++++++
# Check NUM_OF_NODES and NUM_OF_HOSTS in proeprties file

if [[ $NUM_OF_NODES -eq $NUM_OF_HOSTS ]]
then
        echo "Both values are Equal" > /dev/null
else
        echo -e '\033[41mWARNING!!!!\033[0m \033[36m"NUM_OF_HOSTS" and "NUM_OF_NODES" defined in  $LOC/$CLUSTER_PROPERTIES are not equal. Please remove unwanted entries from file or correct "NUM_OF_NODES" value..\033[0m'
        exit 1;
fi

#+++++++++++++++++++++++

if [ -z $PVT_KEY ]
then
        echo -e "\033[32m`timestamp` \033[32mUsing Plain Password For Cluster Setup\033[0m"
        ssh_cmd="sshpass -p $PASSWORD ssh"
        scp_cmd="sshpass -p $PASSWORD scp"
else
        echo -e "\033[32m`timestamp` \033[32mUsing Private Key For Cluster Setup\033[0m"
        ssh_cmd="ssh -i $PVT_KEY"
        scp_cmd="scp -i $PVT_KEY"
        if [ -e $PVT_KEY ]
        then
                echo "File Exist" &> /dev/null
        else
                echo -e "\033[35mPrivate key is missing.. Please check!!!\033[0m"
                exit 1;
        fi
fi
#+++++++++++++++++++++++
prepare_hosts_file()
{
        echo -e  "127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4\n::1         localhost localhost.localdomain localhost6 localhost6.localdomain6" > /tmp/hosts
for host in `grep -w HOST[0-9]* $LOC/$CLUSTER_PROPERTIES|cut -d'=' -f2`
do
        host_ip=`awk "/$host/{getline; print}"  $LOC/$CLUSTER_PROPERTIES|cut -d'=' -f 2`
        echo $host_ip $host.$DOMAIN_NAME >> /tmp/hosts
        if [ "$CLUSTER_PROPERTIES" = "cluster_cloud.props" ]
        then
                sudo sed -i "/$host/d" /etc/hosts
                sudo bash -c "echo \"$host_ip $host.$DOMAIN_NAME\"  >> /etc/hosts"
        fi
done

#+++++++++++++++++++++++
}

####### Generate CM Repo ########
cm_repo()
{
echo "[cm]
name=Cloudera Manager
baseurl=$CM_REPO_URL
gpgcheck=0
enabled=1
priority=1" > /tmp/cm.repo
}

centos_repo()
{
#This will generate internal repo file for Ambari Setup
echo "[Centos7]
name=Centos7
baseurl=http://maxiq:"Uns%40vedD0cument1"@$REPO_SERVER/repo/os/centos7/
gpgcheck=0
enabled=1
priority=1" > /tmp/centos7.repo
}

#+++++++++++++++++++++++
ssh_install_pkgs(){
sudo rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm &> /dev/null
sudo rpm -ivh http://maxiq:"Uns%40vedD0cument1"@$REPO_SERVER/repo/os/centos7/base/Packages/sshpass-1.06-2.el7.x86_64.rpm &> /tmp/sshpass_install.txt
sudo yum -y install unzip wget 2&>1 /dev/null
}
#+++++++++++++++++++++++

localrepo_pre_rep ()
{
        for host in `echo $CM_AGENTS`
        do
                AMBARI_AGENT=`echo $host`.$DOMAIN_NAME
                host_ip=` awk "/$host/{getline; print}"  $LOC/$CLUSTER_PROPERTIES|cut -d'=' -f 2`
                if [ "$CLUSTER_PROPERTIES" = "cluster_cloud.props" ]
                then
        $ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip sudo mkdir /etc/yum.repos.d/bkp 2> /dev/null
                        wait
        $ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip "sudo mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/bkp/"  2> /dev/null
                        wait
        $scp_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  /tmp/cm.repo $USER@$host_ip:/tmp/cm.repo &> /dev/null
                        wait
        $ssh_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip sudo cp /tmp/cm.repo /etc/yum.repos.d/ 2> /dev/null &
                        wait
        $scp_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  /tmp/centos7.repo $USER@$host_ip:/tmp/centos7.repo &> /dev/null
                        wait
        $ssh_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip sudo cp /tmp/centos7.repo /etc/yum.repos.d/ 2> /dev/null
        $ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip sudo yum clean all 2&>1 /dev/null
                fi
        done
}

#+++++++++++++++++++++++
java_install()
{
        echo -e  "\033[32m`timestamp` \033[31mWarning!!! JAVA PATH is not set\033[0m"
        for host in `echo $CM_AGENTS`
        do
                HOST=`echo $host`.$DOMAIN_NAME
                if [ "$CLUSTER_PROPERTIES" = "cluster_cloud.props" ]
                then
                        echo -e  "\033[32m`timestamp` \033[32mInstalling JAVA\033[0m"
                        $ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$HOST sudo yum install -y java-1.8.0-openjdk &> /tmp/java_install.txt
                fi

        done
}
#+++++++++++++++++++++++
bootstrap_hosts()
{
set -x
        echo -e "\033[32m`timestamp` \033[32mBootstrap Hosts \033[0m"
        for host in `echo $CM_AGENTS`
        do
                HOST=`echo $host`.$DOMAIN_NAME
                host_ip=` awk "/$host/{getline; print}"  $LOC/$CLUSTER_PROPERTIES|cut -d'=' -f 2`
                if [ "$CLUSTER_PROPERTIES" = "cluster_cloud.props" ]
                then
                        wait
                        sleep 2
                        $scp_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  /tmp/hosts $USER@$host_ip:/tmp/hosts.org &> /dev/null &
                        wait
                        $ssh_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip sudo mv /tmp/hosts.org /etc/hosts 2> /dev/null &
                        $ssh_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip sudo sed -i.bak "s/$USERNAME-$HOST/$HOST/g" /etc/sysconfig/network  2> /dev/null &
                        $ssh_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip "sudo echo HOSTNAME=$HOST >> /etc/sysconfig/network"  2> /dev/null &

                        printf "sudo hostname "$HOST" 2>/dev/null\nsudo hostnamectl set-hostname "$HOST"\nsudo hostnamectl set-hostname "$HOST" --static\nsudo systemctl restart systemd-hostnamed\nsudo systemctl stop firewalld.service 2>/dev/null\nsudo systemctl disable firewalld.service 2> /dev/null" > /tmp/commands_centos7
                        cat /tmp/commands_centos7|$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip 2>/dev/null
			$ssh_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip "sudo yum install -y cloudera-manager-agent " 2> /dev/null 
			$ssh_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null" $USER@$host_ip "sudo sed -i 's/server_host=localhost/server_host=$CM_SERVER/g' /etc/cloudera-scm-agent/config.ini" 2> /dev/null &
			$ssh_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null" $USER@$host_ip "sudo /etc/init.d/cloudera-scm-agent start" 2> /dev/null 
                fi
	done
}
#+++++++++++++++++++++++

cm_install(){
sudo cd $LOC
sudo sed -i 's:SELINUX=enforcing:SELINUX=disabled:g'  /etc/sysconfig/selinux 
sudo setenforce 0
sudo $wget --user $CM_INSTALLER_BIN
sudo chmod +x $LOC/cloudera-manager-installer.bin
sudo $LOC/cloudera-manager-installer.bin --skip_repo_package=1 --i-agree-to-all-licenses --noprompt --noreadme --nooptions
#sudo rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm &> /dev/null
}
#+++++++++++++++++++++++
######### Generate CDH Repo #########

echo "{
  \"items\" : [ {
    \"name\" : \"CLUSTER_STATS_START\",
    \"value\" : \"10/22/2012 4:50\",
    \"sensitive\" : false
  }, {
    \"name\" : \"REMOTE_PARCEL_REPO_URLS\",
    \"value\" : "\"$CDH_PARCEL_REPO\"",
    \"sensitive\" : false
  } ]
}" > $LOC/repo.json
#++++++++++++++++++++++++++++++++
######### Template Function  #########
cdh_version()
{
echo "{
  \"cdhVersion\" : \"5.14.0\",
  \"displayName\" : \"$CLUSTERNAME\",
  \"cmVersion\" : \"5.14.0\",
  \"repositories\" : [ \"$CDH_PARCEL_REPO\" ],
  \"products\" : [ {
    \"version\" : \"5.14.0-1.cdh5.14.0.p0.24\",
    \"product\" : \"CDH\"
  } ],"
}

get_services()
{
echo "  \"services\" : [ {
    \"refName\" : \"zookeeper\",
    \"serviceType\" : \"ZOOKEEPER\",
    \"roleConfigGroups\" : [ {
      \"refName\" : \"zookeeper-SERVER-BASE\",
      \"roleType\" : \"SERVER\",
      \"base\" : true
    } ]
  }, {
    \"refName\" : \"hdfs\",
    \"serviceType\" : \"HDFS\",
    \"roleConfigGroups\" : [ {
      \"refName\" : \"hdfs-DATANODE-BASE\",
      \"roleType\" : \"DATANODE\",
      \"base\" : true
    }, {
      \"refName\" : \"hdfs-NAMENODE-BASE\",
      \"roleType\" : \"NAMENODE\",
      \"base\" : true
    }, {
      \"refName\" : \"hdfs-BALANCER-BASE\",
      \"roleType\" : \"BALANCER\",
      \"base\" : true
    }, {
      \"refName\" : \"hdfs-SECONDARYNAMENODE-BASE\",
      \"roleType\" : \"SECONDARYNAMENODE\",
      \"base\" : true
    }, {
      \"refName\" : \"hdfs-DATANODE-1\",
      \"roleType\" : \"DATANODE\",
      \"base\" : false
    } ]
  }, {
    \"refName\" : \"hbase\",
    \"serviceType\" : \"HBASE\",
    \"serviceConfigs\" : [ {
      \"name\" : \"zookeeper_service\",
      \"ref\" : \"zookeeper\"
    }, {
      \"name\" : \"hdfs_service\",
      \"ref\" : \"hdfs\"
    } ],
    \"roleConfigGroups\" : [ {
      \"refName\" : \"hbase-REGIONSERVER-BASE\",
      \"roleType\" : \"REGIONSERVER\",
      \"base\" : true
    }, {
      \"refName\" : \"hbase-MASTER-BASE\",
      \"roleType\" : \"MASTER\",
      \"base\" : true
    } ]
  }, {
    \"refName\" : \"yarn\",
    \"serviceType\" : \"YARN\",
    \"roleConfigGroups\" : [ {
      \"refName\" : \"yarn-RESOURCEMANAGER-BASE\",
      \"roleType\" : \"RESOURCEMANAGER\",
      \"base\" : true
    }, {
      \"refName\" : \"yarn-JOBHISTORY-BASE\",
      \"roleType\" : \"JOBHISTORY\",
      \"base\" : true
    }, {
      \"refName\" : \"yarn-NODEMANAGER-BASE\",
      \"roleType\" : \"NODEMANAGER\",
      \"base\" : true
    } ]
  }, {
    \"refName\" : \"spark_on_yarn\",
    \"serviceType\" : \"SPARK_ON_YARN\",
    \"serviceConfigs\" : [ {
      \"name\" : \"yarn_service\",
      \"ref\" : \"yarn\"
    } ],
    \"roleConfigGroups\" : [ {
      \"refName\" : \"spark_on_yarn-SPARK_YARN_HISTORY_SERVER-BASE\",
      \"roleType\" : \"SPARK_YARN_HISTORY_SERVER\",
      \"base\" : true
    }, {
      \"refName\" : \"spark_on_yarn-GATEWAY-BASE\",
      \"roleType\" : \"GATEWAY\",
      \"base\" : true
    } ]
  }, {
    \"refName\" : \"hive\",
    \"serviceType\" : \"HIVE\",
    \"serviceConfigs\" : [ {
      \"name\" : \"hive_metastore_database_user\",
      \"variable\" : \"hive-hive_metastore_database_user\"
    }, {
      \"name\" : \"hive_metastore_database_type\",
      \"variable\" : \"hive-hive_metastore_database_type\"
    }, {
      \"name\" : \"hive_metastore_database_host\",
      \"variable\" : \"hive-hive_metastore_database_host\"
    }, {
      \"name\" : \"hive_metastore_database_name\",
      \"variable\" : \"hive-hive_metastore_database_name\"
    }, {
      \"name\" : \"hive_metastore_database_password\",
      \"variable\" : \"hive-hive_metastore_database_password\"
    }, {
      \"name\" : \"hive_metastore_database_port\",
      \"variable\" : \"hive-hive_metastore_database_port\"
    }, {
      \"name\" : \"mapreduce_yarn_service\",
      \"ref\" : \"yarn\"
    }, {
      \"name\" : \"zookeeper_service\",
      \"ref\" : \"zookeeper\"
    } ],
    \"roleConfigGroups\" : [ {
      \"refName\" : \"hive-HIVESERVER2-BASE\",
      \"roleType\" : \"HIVESERVER2\",
      \"base\" : true
    }, {
      \"refName\" : \"hive-HIVEMETASTORE-BASE\",
      \"roleType\" : \"HIVEMETASTORE\",
      \"base\" : true
    }, {
      \"refName\" : \"hive-WEBHCAT-BASE\",
      \"roleType\" : \"WEBHCAT\",
      \"base\" : true
    }, {
      \"refName\" : \"hive-GATEWAY-BASE\",
      \"roleType\" : \"GATEWAY\",
      \"base\" : true
    } ]
  } ],"
}

get_addhost_template(){
echo "\"hostTemplates\" : [ {
    \"refName\" : \"HostTemplate-$i-from-$HST_NAME_HOSTNAME.$DOMAIN_NAME\",
    \"cardinality\" : 1,
    \"roleConfigGroupsRefNames\" : [ $SERVICES_LIST ]
  }, {"
}

get_addhostadd_template(){
    echo "\"refName\" : \"HostTemplate-$i-from-$HST_NAME_HOSTNAME.$DOMAIN_NAME\",
    \"cardinality\" : 1,
    \"roleConfigGroupsRefNames\" : [ $SERVICES_LIST ]
  }, {"
}

get_last_template(){
echo "    \"refName\" : \"HostTemplate-$i-from-$HST_NAME_HOSTNAME.$DOMAIN_NAME\",
    \"cardinality\" : 1,
    \"roleConfigGroupsRefNames\" : [ $SERVICES_LIST ]
  } ],"
}


instantiator_template(){
echo "\"instantiator\" : {
    \"clusterName\" : \"$CLUSTERNAME\",
    \"hosts\" : [ {"
}

instantiator1_template(){
      echo "\"hostName\" : \"$HST_NAME_HOSTNAME.$DOMAIN_NAME\",
      \"hostTemplateRefName\" : \"HostTemplate-$i-from-$HST_NAME_HOSTNAME.$DOMAIN_NAME\"
    }, {"
}

instantiator_final_template(){
      echo "\"hostNameRange\" : \"$HST_NAME_HOSTNAME.$DOMAIN_NAME\",
      \"hostTemplateRefName\" : \"HostTemplate-$i-from-$HST_NAME_HOSTNAME.$DOMAIN_NAME\"
    } ],
    \"variables\" : [ {
      \"name\" : \"hive-hive_metastore_database_host\",
      \"value\" : \"node2.example.com\"
    }, {
      \"name\" : \"hive-hive_metastore_database_name\",
      \"value\" : \"hive1\"
    }, {
      \"name\" : \"hive-hive_metastore_database_password\",
      \"value\" : \"hive1\"
    }, {
      \"name\" : \"hive-hive_metastore_database_port\",
      \"value\" : \"7432\"
    }, {
      \"name\" : \"hive-hive_metastore_database_type\",
      \"value\" : \"postgresql\"
    }, {
      \"name\" : \"hive-hive_metastore_database_user\",
      \"value\" : \"hive1\"
    } ],

    \"roleConfigGroups\" : [ {
      \"rcgRefName\" : \"hdfs-DATANODE-1\",
      \"name\" : \"\"
    } ]
  }
}"
}


######### Template Function  #########




generate_json()
{
cdh_version > $LOC/$out_file.json
echo -e "\n" >> $LOC/$out_file.json
get_services >> $LOC/$out_file.json
echo -e "\n" >> $LOC/$out_file.json

#---------------------------------------------------------
i=0
for HOST in `grep -w 'HOST[0-9]*' $LOC/$PROPS|tr '\n' ' '`
do
        HST_NAME_VAR=`echo $HOST|cut -d'=' -f1`
        if [ $HST_NAME_VAR == $START_HST_NAME ]
        then
                i=$[$i+1]
                HST_NAME_HOSTNAME=`echo $HOST|cut -d'=' -f2`
                SERVICES_LIST=`cat $LOC/$PROPS|grep "$HST_NAME_VAR"_SERVICES |awk -F"=" '{print $2}'|sed 's/,/", "/g'|sed -e 's/[^ ]*CLIENT"[^ ]*//ig'|sed 's/" /"/g'`
                SERVICES_LIST=`echo $SERVICES_LIST | sed 's/,$//'`
                get_addhost_template >> $LOC/$out_file.json
        elif [ $HST_NAME_VAR == $LAST_HST_NAME ]
        then
                i=$[$i+1]
                HST_NAME_HOSTNAME=`echo $HOST|cut -d'=' -f2`
                SERVICES_LIST=`cat $LOC/$PROPS|grep "$HST_NAME_VAR"_SERVICES |awk -F"=" '{print $2}'|sed 's/,/", "/g'|sed -e 's/[^ ]*CLIENT"[^ ]*//ig'|sed 's/" /"/g'`
                #SERVICES_LIST=`cat $LOC/$PROPS|grep "$HST_NAME_VAR"_SERVICES |awk -F"=" '{print $2}'|sed 's/,/", "/g'|sed -e 's/[^ ]*CLIENT"[^ ]*//ig'|sed 's/" /"/g'|sed 's/ "//g'`
                SERVICES_LIST=`echo $SERVICES_LIST| sed 's/"$//g'`
                SERVICES_LIST=`echo $SERVICES_LIST| sed 's/,$//g'`
                get_last_template >> $LOC/$out_file.json
        else
                i=$[$i+1]
                HST_NAME_HOSTNAME=`echo $HOST|cut -d'=' -f2`
                SERVICES_LIST=`cat $LOC/$PROPS|grep "$HST_NAME_VAR"_SERVICES |awk -F"=" '{print $2}'|sed 's/,/", "/g'|sed -e 's/[^ ]*CLIENT"[^ ]*//ig'|sed 's/" /"/g'`
                #SERVICES_LIST=`cat $LOC/$PROPS|grep "$HST_NAME_VAR"_SERVICES |awk -F"=" '{print $2}'|sed 's/,/", "/g'|sed -e 's/[^ ]*CLIENT"[^ ]*//ig'|sed 's/" /"/g'|sed 's/ "//g'`
                SERVICES_LIST=`echo $SERVICES_LIST| sed 's/"$//g'`
                SERVICES_LIST=`echo $SERVICES_LIST| sed 's/,$//g'`
                get_addhostadd_template >> $LOC/$out_file.json
        fi
done
#---------------------------------------------------------

echo -e "\n" >> $LOC/$out_file.json

#---------------------------------------------------------
i=0
for HOST in `grep -w 'HOST[0-9]*' $LOC/$PROPS|tr '\n' ' '`
do
        HST_NAME_VAR=`echo $HOST|cut -d'=' -f1`
        if [ $HST_NAME_VAR == $START_HST_NAME ]
        then
                i=$[$i+1]
                HST_NAME_HOSTNAME=`echo $HOST|cut -d'=' -f2`
                instantiator_template >> $LOC/$out_file.json
                instantiator1_template >> $LOC/$out_file.json
        elif [ $HST_NAME_VAR == $LAST_HST_NAME ]
        then
                i=$[$i+1]
                HST_NAME_HOSTNAME=`echo $HOST|cut -d'=' -f2`
                instantiator_final_template >> $LOC/$out_file.json
        else
                i=$[$i+1]
                HST_NAME_HOSTNAME=`echo $HOST|cut -d'=' -f2`
                instantiator1_template >> $LOC/$out_file.json
        fi
done
}
#---------------------------------------------------------

set_cdh_repo(){
curl -X PUT -H "Content-Type:application/json" -u admin:admin -X PUT --data @$LOC/repo.json http://$CM_SERVER:7180/api/v19/cm/config &> /tmp/set_cdh_repo
}

import_cluster(){
curl -X POST -H "Content-Type: application/json" -d @$out_file.json  http://admin:admin@$CM_SERVER:7180/api/v12/cm/importClusterTemplate &> /tmp/import_cluster
}





ssh_install_pkgs
prepare_hosts_file
cm_repo
centos_repo
localrepo_pre_rep
java_install
bootstrap_hosts
cm_install
port=`nc -w 1  localhost 7180 </dev/null`
status=`echo $?`
until [ "$status"  == "0" ]; do
  echo "Waiting jenkins to launch on 7180..."
  sleep 5
done
generate_json
set_cdh_repo
import_cluster


