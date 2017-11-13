# -*- mode: ruby -*-
# vi: set ft=ruby :

hosts = {
  "docker-nodes01" => "192.168.33.201",
  "docker-nodes02" => "192.168.33.202",
  "infra-devops" => "192.168.33.100"
}

File.open("./hosts", 'w+') { |file| 
  hosts.each do |name,ip|
    file.write("#{ip} #{name} #{name}\n")
    if name == "infra-devops" then
      file.write("#{ip} docker.artifactory docker.artifactory\n")
    end
  end
}

$script = <<'SCRIPT'

rm -f /etc/yum.repos.d/*
wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
wget -O /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo 
yum clean all && yum makecache

yum -y install ntp java yum-utils deltarpm python-setuptools docker-compose unzip git sshpass
yum -y localinstall --disablerepo=*  /vagrant/rpms/*.rpm
chmod a+x /vagrant/rpms/bin/*

unalias cp
cp -f /vagrant/rpms/bin/* /usr/bin
easy_install -i http://mirrors.aliyun.com/pypi/simple/ pip
/usr/sbin/ntpdate 3.cn.pool.ntp.org
#curl -sSL https://get.daocloud.io/daotools/set_mirror.sh | sh -s http://a0dd9923.m.daocloud.io
echo '{"registry-mirrors": ["https://97ueh6cd.mirror.aliyuncs.com"]}' > /etc/docker/daemon.json

sed -i 's/ExecStart=.*/ExecStart=\/usr\/bin\/dockerd --insecure-registry docker.artifactory:8000/' /usr/lib/systemd/system/docker.service 

systemctl daemon-reload
systemctl stop ntpd docker.service
systemctl enable ntpd docker.service
systemctl start ntpd docker.service
systemctl stop firewalld  
systemctl disable firewalld

echo root | passwd --stdin root
echo -e "\n" | ssh-keygen -N "" &> /dev/null
sed  -i '/^export PS1=/d' ~/.bash_profile
echo "export PS1='[\[\e[32;1m\]\u@\h:\w]\[\e[0m\]\\$'" >> ~/.bash_profile
rm -f /etc/localtime ; cp  /usr/share/zoneinfo/Asia/Shanghai /etc/localtime 
sed -i 's/SELINUX=permissive/SELINUX=disabled/g' /etc/selinux/config
setenforce 0
sysctl -w vm.overcommit_memory=1
SCRIPT

Vagrant.configure("2") do |config|
  hosts.each do |name, ip|
    config.vm.define name do |machine|
      machine.vm.box = "cmdt/centos-7.3"
      machine.vm.box_check_update = false
      machine.ssh.insert_key = false
      machine.vm.hostname = name
      machine.vm.network :private_network, ip: ip
      machine.vm.synced_folder ".", "/vagrant"
      machine.vm.provision "shell", inline: $script
      machine.vm.provider "virtualbox" do |v|
          v.name = name
        if name == "infra-devops" then
          v.cpus = 4
          v.customize ["modifyvm", :id, "--memory", 6144]
        else
          v.cpus = 1
          v.customize ["modifyvm", :id, "--memory", 2048]          
        end
     end
     machine.vm.provision "file", source: "hosts", destination: "/tmp/hosts"
     machine.vm.provision "shell", inline: "cat /tmp/hosts >> /etc/hosts", privileged: true
    end
  end
end
