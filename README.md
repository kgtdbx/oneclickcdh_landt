Steps:

1. Clone git repo 
$git clone https://hadoop_automation@bitbucket.org/hadoop_automation/cdh_oneclick_deploy.git
2. cd ~/cdh_oneclick_deploy
3. Modify cluster.props file as per guidelines mentioned in the cluster_cloud.props file.
$chmod 755 cdh_deploy.sh
4. Execute cluster deploy script
$./cdh_deploy.sh cluster_cloud.props
5. Above process will take little bit time to setup and deploy cluster. Once done you can browse CM UI using below command from browser -
http://<cloudera_manager_host_ip>:7180/
6. To create MaxiqQueue please execute below command -
$./queue.sh cluster_cloud.props
