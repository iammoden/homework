#!/bin/bash
##author: Fei.su@cm-dt.com
##version: 20171113-1950

echo 因国内有墙，非dockhub(官网国内有加速器)的境外境像基本下载不了
echo 所以先采用本地导入部分images，节约部署时间
cd /vagrant/Deploy/images/;for images in `ls *.tar`; do docker load < $images; done


echo 构建部署环境
cd /vagrant/Deploy/; tar -xvf jenkins-pipeline.tar.gz
cd /vagrant/Deploy/jenkins-pipeline; docker-compose up -d
echo -n "wait for starting jenkins";
until [[ "200" == ""$(curl -L -s -o /dev/null -w "%{http_code}" 192.168.33.100:8080)"" ]]; do echo -n ".";sleep 1; done; echo



echo 构建gitlab
cd /vagrant/Deploy/gitlab/; docker-compose up -d

echo -n "wait for starting gitlab"
until [[ "200" == ""$(curl -L -s -o /dev/null -w "%{http_code}" http://127.0.0.1:10080/)"" ]]; do echo -n ".";sleep 1; done;echo


echo 创建project
yum install jq -y >/dev/null
Token=$(curl -L -s http://127.0.0.1:10080/api/v3/session --data 'login=root&password=password' | jq .  | grep private_token | awk -F'"' '{print $4}')

curl -X POST --header "PRIVATE-TOKEN: $Token" "http://127.0.0.1:10080/api/v4/projects/?name=sufei-demo&visibility=public" -d '{"visibility": "public"}'

echo  生成密钥(token)
curl -X POST --header "PRIVATE-TOKEN: $Token" "http://127.0.0.1:10080/api/v4/user/keys" --header "Content-Type: application/json" --data '{"title": "root@infra-devops", "key": "'"$(cat ~/.ssh/id_rsa.pub)"'"}'


echo 初始化git,自动上传代码
cp -a /vagrant/Deploy/gitlab/sufei-demo ~/
cd ~/sufei-demo/
git init
git remote add origin ssh://git@localhost:10022/root/sufei-demo.git
git add .
git config --global user.email "fei.su@cm-dt.com"
git config --global user.name "Su Fei"
git commit -m "Initial commit"
ssh-keyscan -p 10022 localhost  > ~/.ssh/known_hosts
git push -u origin master


echo 部署生产环境基础设施
yum install sshpass -y
export SSHPASS=root
first_node="yes"
swarm_join=""
for host in $(cat /etc/hosts | grep node | awk '{print $1}') ; do 
ssh-keyscan -p 22 $host  >> ~/.ssh/known_hosts
sshpass -e ssh-copy-id -i ~/.ssh/id_rsa.pub  root@$host
if [[ $first_node == "yes" ]]; then 
  first_node="no";
  ssh root@$host docker swarm init --advertise-addr=$host
  export swarm_join=$(ssh root@$host docker swarm join-token manager | tail -n +3 | sed 's/\\//g');
else
  ssh root@$host $swarm_join
fi
ssh root@$host /vagrant/Server/rollout-docker-swarm.sh
done