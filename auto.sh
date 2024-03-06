#!/bin/bash
apt-get install ceph-common -y

ceph auth get-or-create client.glance mon 'allow r' osd 'allow class-read object_prefix rbd_children, allow rwx pool=images' -o /etc/ceph/ceph.client.glance.keyring
ceph auth get-or-create client.cinder mon 'allow r' osd 'allow class-read object_prefix rbd_children, allow rwx pool=volumes, allow rwx pool=images' -o /etc/ceph/ceph.client.cinder.keyring
ceph auth get-or-create client.nova mon 'allow r' osd 'allow class-read object_prefix rbd_children, allow rwx pool=vms, allow rx pool=images' -o /etc/ceph/ceph.client.nova.keyring
ceph auth get-or-create client.cinder-backup mon 'allow r' osd 'allow class-read object_prefix rbd_children, allow rwx pool=backups' -o /etc/ceph/ceph.client.cinder-backup.keyring

ceph status; ceph osd tree; ceph df
ceph orch ps; ceph osd pool ls
ls -lh /etc/ceph/

apt-get update -y
apt-get install python3-dev libffi-dev gcc libssl-dev python3-selinux python3-setuptools python3-venv -y

python3 -m venv kolla-venv
echo "source ~/kolla-venv/bin/activate" >> ~/.bashrc
source ~/kolla-venv/bin/activate

pip install -U pip
pip install 'ansible-core>=2.14,<2.16'
ansible --version
pip install git+https://opendev.org/openstack/kolla-ansible@master

mkdir -p /etc/kolla
chown $USER:$USER /etc/kolla

cp -r ~/kolla-venv/share/kolla-ansible/etc_examples/kolla/* /etc/kolla
cp ~/kolla-venv/share/kolla-ansible/ansible/inventory/* .

kolla-ansible install-deps

mkdir /etc/ansible
cp ansible.cfg /etc/ansible/ansible.cfg
cp multinode-template multinode

kolla-genpwd

mkdir /etc/kolla/config
mkdir /etc/kolla/config/nova
mkdir /etc/kolla/config/glance
mkdir -p /etc/kolla/config/cinder/cinder-volume
mkdir /etc/kolla/config/cinder/cinder-backup
cp /etc/ceph/ceph.conf /etc/kolla/config/cinder/
cp /etc/ceph/ceph.conf /etc/kolla/config/nova/
cp /etc/ceph/ceph.conf /etc/kolla/config/glance/
cp /etc/ceph/ceph.client.glance.keyring /etc/kolla/config/glance/
cp /etc/ceph/ceph.client.nova.keyring /etc/kolla/config/nova/
cp /etc/ceph/ceph.client.cinder.keyring /etc/kolla/config/nova/
cp /etc/ceph/ceph.client.cinder.keyring /etc/kolla/config/cinder/cinder-volume/
cp /etc/ceph/ceph.client.cinder.keyring /etc/kolla/config/cinder/cinder-backup/
cp /etc/ceph/ceph.client.cinder-backup.keyring /etc/kolla/config/cinder/cinder-backup/

for node in controller{2..3} compute{1..2}
do
  scp -r /etc/ceph/ root@$node:/etc/
done

cp globals.yml /etc/kolla/globals.yml
