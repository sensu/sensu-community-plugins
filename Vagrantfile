# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = '2'

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  config.vm.box = 'chef/centos-6.5'
  config.vm.box_download_checksum = true
  config.vm.box_download_checksum_type = 'md5'
  config.vm.hostname = 'sensu-community-plugins-dev'
  config.vm.post_up_message = 'this is a test'

  script = <<EOF
sudo yum update -y
sudo yum groupinstall -y development
sudo yum install -y vim nano
gpg2 --keyserver hkp://keys.gnupg.net --recv-keys D39DC0E3
curl -L get.rvm.io | bash -s stable
source /home/vagrant/.rvm/scripts/rvm
rvm reload
#rvm install 1.8.7
rvm install 1.9.2
rvm install 1.9.3
rvm install 2.1.4
rvm install 2.0.0
#rvm use 1.8.7@sensu_plugins --create
rvm use 1.9.3@sensu_plugins --create
rvm use 1.9.2@sensu_plugins --create
rvm use 2.0.0@sensu_plugins --create
rvm use 2.1.4@sensu_plugins --create
rvm use 2.1.4@sensu_plugins --default
EOF
  config.vm.provision 'shell', inline: script, privileged: false

  # config.vm.network "forwarded_port", guest: 80, host: 8080
  # config.vm.network "private_network", ip: "192.168.33.10"
end
