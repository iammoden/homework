#!/bin/bash

##�������ǽ����dockhub(���������м�����)�ľ��⾳��������ز���
##�����Ȳ��ñ��ص��벿��images����Լ����ʱ��
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


###��docker-node01��docker-node02�϶�����
export HOST_IP=$(cat /etc/hosts | grep `hostname` | grep -v "127.0.0.1" | awk '{print $1}')
cd /vagrant/Server/consul-template-demo
docker-compose up -d

