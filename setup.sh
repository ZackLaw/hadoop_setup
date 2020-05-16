#!/bin/bash
##################################################
# This is an interactive setup script ############ 
# Written by Zack Luo, Tandon ECE, 5/12/2020 #####
# Run with "sudo bash" under home directory ######
##################################################

echo
printf "*%.0s" {1..8}
echo -e "\nUpdating"
printf "*%.0s" {1..8}
echo
echo
apt-get update

echo
printf "*%.0s" {1..15}
echo -e "\nInstalling Java" 
printf "*%.0s" {1..15}
echo
echo
apt-get -y install openjdk-8-jdk-headless

echo
printf "*%.0s" {1..14}
echo -e "\nJava Installed"
printf "*%.0s" {1..14}
echo

echo
printf "*%.0s" {1..17}
echo -e "\nInstalling Hadoop"
printf "*%.0s" {1..17}
echo
echo
if [ ! -d ${HOME}/hadoop-3.2.1 ];then
      wget https://mirrors.sonic.net/apache/hadoop/common/hadoop-3.2.1/hadoop-3.2.1.tar.gz
      tar xvzf hadoop-3.2.1.tar.gz
      rm -f hadoop-3.2.1.tar.gz
      chown -R ubuntu:ubuntu hadoop-3.2.1
else  echo "Already Installed"
fi
sed -i s/"# export JAVA_HOME="/"export JAVA_HOME=\/usr\/lib\/jvm\/java-8-openjdk-amd64"/g ${HOME}/hadoop-3.2.1/etc/hadoop/hadoop-env.sh

echo
printf "*%.0s" {1..16}
echo -e "\nHadoop Installed"
printf "*%.0s" {1..16}
echo

sed -i s/"#   StrictHostKeyChecking ask"/"StrictHostKeyChecking no"/g /etc/ssh/ssh_config
if [ ! -f ${HOME}/.ssh/id_rsa ];then
      ssh-keygen -f ${HOME}/.ssh/id_rsa -P "" -q
      chown ubuntu:ubuntu ${HOME}/.ssh/id_rsa ${HOME}/.ssh/id_rsa.pub
      cat ${HOME}/.ssh/id_rsa.pub >> ${HOME}/.ssh/authorized_keys 
fi

echo
echo "Which mode of cluster?[single|multiple]"
read mode
while [ $mode != single ] && [ $mode != multiple ];do
      echo
      echo "You can only choose either option in the brackets"
      read mode
done

if [ $mode == single ];then
      echo
      echo "Standalone or Pseudo-Distributed?[standalone|pseudo]"
      read single_mode
      if [ $single_mode == pseudo ];then
            echo
            echo "The pseudo mode is HDFS without YARN due to limited capacity of free tier account"
            echo "So start dfs but not yarn"
            echo localhost > ${HOME}/hadoop-3.2.1/etc/hadoop/workers
            
            sed -i "/<configuration>/,/<\/configuration>/d" ${HOME}/hadoop-3.2.1/etc/hadoop/core-site.xml
            sed -i "/<configuration>/,/<\/configuration>/d" ${HOME}/hadoop-3.2.1/etc/hadoop/yarn-site.xml
            sed -i "/<configuration>/,/<\/configuration>/d" ${HOME}/hadoop-3.2.1/etc/hadoop/mapred-site.xml
core_site="<configuration>\n"\
"<property>\n"\
"<name>fs.defaultFS</name>\n"\
"<value>hdfs://localhost:9000</value>\n"\
"</property>\n"\
"</configuration>"
yarn_site="<configuration>\n</configuration>"
mapred_site="<configuration>\n</configuration>"
            echo -e $core_site >> ${HOME}/hadoop-3.2.1/etc/hadoop/core-site.xml
            echo -e $yarn_site >> ${HOME}/hadoop-3.2.1/etc/hadoop/yarn-site.xml
            echo -e $mapred_site >> ${HOME}/hadoop-3.2.1/etc/hadoop/mapred-site.xml
      fi
else
      echo
      echo "Is this the NameNode?[y|n]"
      read is_NN
      if [ $is_NN == y ];then
            echo
            echo "Please input the NameNode's Public DNS"
            read NN
            echo
            echo "Is the ResourceManager on the same host with the NameNode?[y|n]"
            read With_NN
            if [ $With_NN == n ];then
                  echo
                  echo "Please input the ResourceManager's Public DNS"
                  read RM
            else  RM=$NN
            fi
            echo
            echo "How many DataNodes?"
            read NUM
            echo "" > ${HOME}/hadoop-3.2.1/etc/hadoop/workers
            num=1
            while [ $num -le $NUM ];do
                  echo
                  echo "Please input the DataNode${num}'s Public DNS"
                  read DN
                  echo $DN >> ${HOME}/hadoop-3.2.1/etc/hadoop/workers
                  (( num++ ))
            done

            sed -i "/<configuration>/,/<\/configuration>/d" ${HOME}/hadoop-3.2.1/etc/hadoop/core-site.xml
            sed -i "/<configuration>/,/<\/configuration>/d" ${HOME}/hadoop-3.2.1/etc/hadoop/yarn-site.xml
            sed -i "/<configuration>/,/<\/configuration>/d" ${HOME}/hadoop-3.2.1/etc/hadoop/mapred-site.xml

core_site="<configuration>\n"\
"<property>\n"\
"<name>fs.defaultFS</name>\n"\
"<value>hdfs://${NN}:9000</value>\n"\
"</property>\n"\
"</configuration>"

yarn_site="<configuration>\n"\
"<property>\n"\
"<name>yarn.nodemanager.aux-services</name>\n"\
"<value>mapreduce_shuffle</value>\n"\
"</property>\n"\
"<property>\n"\
"<name>yarn.nodemanager.env-whitelist</name>\n"\
"<value>JAVA_HOME,HADOOP_COMMON_HOME,HADOOP_HDFS_HOME,HADOOP_CONF_DIR,CLASSPATH_PREPEND_DISTCACHE,HADOOP_YARN_HOME,HADOOP_MAPRED_HOME</value>\n"\
"</property>\n"\
"<property>\n"\
"<name>yarn.nodemanager.resource.memory-mb</name>\n"\
"<value>1024</value>\n"\
"</property>\n"\
"<property>\n"\
"<name>yarn.resourcemanager.hostname</name>\n"\
"<value>${RM}</value>\n"\
"</property>\n"\
"</configuration>"

mapred_site="<configuration>\n"\
"<property>\n"\
"<name>mapreduce.framework.name</name>\n"\
"<value>yarn</value>\n"\
"</property>\n"\
"<property>\n"\
"<name>mapreduce.application.classpath</name>\n"\
"<value>\$HADOOP_MAPRED_HOME/share/hadoop/mapreduce/*:\$HADOOP_MAPRED_HOME/share/hadoop/mapreduce/lib/*</value>\n"\
"</property>\n"\
"<property>\n"\
"<name>yarn.app.mapreduce.am.resource.mb</name>\n"\
"<value>100</value>\n"\
"</property>\n"\
"</configuration>"

            echo -e $core_site >> ${HOME}/hadoop-3.2.1/etc/hadoop/core-site.xml
            echo -e $yarn_site >> ${HOME}/hadoop-3.2.1/etc/hadoop/yarn-site.xml
            echo -e $mapred_site >> ${HOME}/hadoop-3.2.1/etc/hadoop/mapred-site.xml

            echo
            echo "Please copy the AWS private key .pem file to all the DataNode's home directory"

      else  echo
            echo "Is the NameNode setup already?[y|n]"
            read is_NNSetup
            if [ $is_NNSetup == n ];then
                  echo
                  echo "Please set up the NameNode first"
                  exit
            fi
            echo
            echo "Please input the filename of AWS private key .pem file"
            read pem
            if [ ! -f $pem ];then
                  echo
                  echo "Please copy the correct AWS private key file here before DataNode setup"
                  exit
            fi
            echo
            echo "Please input the NameNode's Public DNS"
            read NN
            scp -i ${pem} ubuntu@${NN}:${HOME}/.ssh/id_rsa.pub ${HOME}
            cat id_rsa.pub >> ${HOME}/.ssh/authorized_keys
            scp -i ${pem} ubuntu@${NN}:${HOME}/hadoop-3.2.1/etc/hadoop/core-site.xml ${HOME}/hadoop-3.2.1/etc/hadoop
            scp -i ${pem} ubuntu@${NN}:${HOME}/hadoop-3.2.1/etc/hadoop/yarn-site.xml ${HOME}/hadoop-3.2.1/etc/hadoop
            scp -i ${pem} ubuntu@${NN}:${HOME}/hadoop-3.2.1/etc/hadoop/mapred-site.xml ${HOME}/hadoop-3.2.1/etc/hadoop
      fi
fi

echo
printf "*%.0s" {1..19}
echo -e "\nSet Up Successfully"
printf "*%.0s" {1..19}
echo
