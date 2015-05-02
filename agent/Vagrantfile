# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

provision_script = <<SCRIPT
sudo mkdir /var/lib/docker
sudo apt-get install -y btrfs-tools
sudo mkfs.btrfs /dev/sdb
sudo echo '/dev/sdb	/var/lib/docker	 btrfs	defaults	0 0' >> /etc/fstab
sudo mount -a
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 36A1D7869245C8950F966E92D8576A8BA88D21E9
sudo echo deb https://get.docker.com/ubuntu docker main > /etc/apt/sources.list.d/docker.list
sudo apt-get update
sudo apt-get install -y -q lxc-docker python-pip
sudo dpkg -i /vagrant/packaging/ubuntu/kontena-weave_0.1.0-1_all.deb
sudo echo 'DOCKER_OPTS="-s btrfs --bridge=weave --fixed-cidr=%s --dns 8.8.8.8 --dns 8.8.4.4"' >> /etc/default/docker
sudo restart docker
sudo pip install docker-compose
sudo gpasswd -a vagrant docker
SCRIPT

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  3.times do |i|
    node_number = i + 1
    config.vm.define "docker#{node_number}" do |docker|
      docker.vm.box = "ubuntu/trusty64"
      docker.vm.network "private_network", ip: "192.168.66.#{node_number + 1}"
      docker.vm.hostname = "node-#{node_number}"
      docker.vm.provider "virtualbox" do |vb|
        vb.gui = false
        vb.customize ["modifyvm", :id, "--memory", "768"]
        vb.auto_nat_dns_proxy = false
        vb.customize ["modifyvm", :id, "--natdnsproxy1", "off" ]
        vb.customize ["modifyvm", :id, "--natdnshostresolver1", "off" ]
        lfs_disk = "virtualbox/agent_docker_#{node_number}" + ".vdi"
        unless File.exist?(lfs_disk)
            vb.customize ['createhd', '--filename', lfs_disk, '--size', 20 * 1024]
        end
         vb.customize ['storageattach', :id, '--storagectl', 'SATAController', '--port', 1, '--device', 0, '--type', 'hdd', '--medium', lfs_disk]
      end
      docker.vm.provision "shell", inline: (provision_script % ["10.81.#{i + 1}.0/24"])
    end

  end


end
