# -*- mode: ruby -*-
# vi: set ft=ruby :

# Modify these for your system
CPUS = 2
MEMORY = "2048"

Vagrant.configure(2) do |config|
    config.vm.box = "ubuntu/trusty64"
    config.vm.network "forwarded_port", guest: 8000, host: 8000

    config.vm.provider "virtualbox" do |vb|
        vb.memory = MEMORY
        vb.cpus = CPUS
    end

    config.vm.provision "shell", privileged: false, path: "provision.sh"
end
