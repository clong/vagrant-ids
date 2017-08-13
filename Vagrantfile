# -*- mode: ruby -*-
# vi: set ft=ruby :
Vagrant.configure("2") do |cfg|
  cfg.vm.box = "bento/ubuntu-16.04"
  cfg.vm.provision :shell, path: "bootstrap.sh"
  cfg.vm.provider "vmware_fusion" do |v, override|
    v.memory = 4096
    v.cpus = 2
    v.gui = true
  end
  cfg.vm.provider "virtualbox" do |v, override|
    v.memory = 4096
    v.cpus = 2
    v.gui = true
  end
end
