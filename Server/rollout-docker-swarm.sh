#!/bin/bash

##因国内有墙，非dockhub(官网国内有加速器)的境外境像基本下载不了
##所以先采用本地导入部分images，节约部署时间
cd /vagrant/Server/images/
for image in $(ls *.tar); do docker load < $image ; done

yum install socat -y
cat << EOF > /etc/systemd/system/socat.service
[Service]
ExecStart=/usr/bin/socat TCP4-LISTEN:2375,fork,reuseaddr UNIX-CONNECT:/var/run/docker.sock
EOF

systemctl daemon-reload
systemctl enable socat.service
systemctl start socat.service


###在docker-node01和docker-node02上都运行
export HOST_IP=$(cat /etc/hosts | grep `hostname` | grep -v "127.0.0.1" | awk '{print $1}')
cd /vagrant/Server/consul-template-demo
docker-compose up -d

