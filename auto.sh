#!/bin/bash

# Update package repositories and install ceph-common package
apt-get update -y
apt-get install ceph-common -y

# Create Ceph clients and generate keyrings
ceph auth get-or-create client.glance mon 'allow r' osd 'allow class-read object_prefix rbd_children, allow rwx pool=images' -o /etc/ceph/ceph.client.glance.keyring
ceph auth get-or-create client.cinder mon 'allow r' osd 'allow class-read object_prefix rbd_children, allow rwx pool=volumes, allow rwx pool=images' -o /etc/ceph/ceph.client.cinder.keyring
ceph auth get-or-create client.nova mon 'allow r' osd 'allow class-read object_prefix rbd_children, allow rwx pool=vms, allow rx pool=images' -o /etc/ceph/ceph.client.nova.keyring
ceph auth get-or-create client.cinder-backup mon 'allow r' osd 'allow class-read object_prefix rbd_children, allow rwx pool=backups' -o /etc/ceph/ceph.client.cinder-backup.keyring

# Display Ceph cluster status and information
ceph status
ceph osd tree
ceph df

# Install dependencies for Kolla-Ansible and create Python virtual environment
apt-get install python3-dev libffi-dev gcc libssl-dev python3-selinux python3-setuptools python3-venv -y
python3 -m venv /root/kolla-venv
source ~/kolla-venv/bin/activate

# Upgrade pip and install ansible-core and Kolla-Ansible
pip install -U pip
pip install 'ansible-core>=2.14,<2.16'
pip install git+https://opendev.org/openstack/kolla-ansible@master

# Copy Kolla-Ansible configuration files and inventory
mkdir -p /etc/kolla
cp -r ~/kolla-venv/share/kolla-ansible/etc_examples/kolla/* /etc/kolla
cp ~/kolla-venv/share/kolla-ansible/ansible/inventory/* .

# Install Kolla-Ansible dependencies
kolla-ansible install-deps

# Configure Ansible
mkdir -p /etc/ansible
cp ansible.cfg /etc/ansible/ansible.cfg
cp multinode-template multinode

# Generate passwords for Kolla-Ansible
kolla-genpwd

# Create configuration directories for OpenStack services
mkdir -p /etc/kolla/config/nova
mkdir -p /etc/kolla/config/glance
mkdir -p /etc/kolla/config/cinder/cinder-volume
mkdir -p /etc/kolla/config/cinder/cinder-backup

# Copy Ceph and client configuration files to Kolla configuration directories
cp /etc/ceph/ceph.conf /etc/kolla/config/cinder/
cp /etc/ceph/ceph.conf /etc/kolla/config/nova/
cp /etc/ceph/ceph.conf /etc/kolla/config/glance/
cp /etc/ceph/ceph.client.glance.keyring /etc/kolla/config/glance/
cp /etc/ceph/ceph.client.nova.keyring /etc/kolla/config/nova/
cp /etc/ceph/ceph.client.cinder.keyring /etc/kolla/config/nova/
cp /etc/ceph/ceph.client.cinder.keyring /etc/kolla/config/cinder/cinder-volume/
cp /etc/ceph/ceph.client.cinder.keyring /etc/kolla/config/cinder/cinder-backup/
cp /etc/ceph/ceph.client.cinder-backup.keyring /etc/kolla/config/cinder/cinder-backup/

# Copy Ceph configuration files to other nodes
for node in controller{2..3} compute{1..2}
do
  scp -r /etc/ceph/ root@$node:/etc/
done

# Copy global Kolla configuration file
cp globals.yml /etc/kolla/globals.yml

echo "Setup completed successfully."
