# Requirements for the control node running Ansible on CentOS 8.3

## Clone the Github project
```
mkdir ~/Projects
cd ~/Projects
git clone https://github.com/jullienl/HPE-Synergy-baremetal
```

## openssh installation
```
yum install openssh
systemctl start sshd.service && systemctl enable sshd.service
```

## Generate an SSH key without a passphrase for the Ansible control node
```
ssh-keygen -t rsa -f /root/.ssh/id_rsa -N ""
``` 

## ISO creation tools required
```
yum install mkisofs
# isohybrid
yum install syslinux
# implantisomd5
yum install isomd5sum
```

## Ansible installation and requirements
```
yum install net-tools
yum install wget
yum install git-all
yum install python3
yum install epel-release
yum install ansible
```

## Installation of ksvalidator (optional, useful to validate kickstart file modifications)
```
yum install pykickstart
```
## Installation of the Ansible Collections used in these playbooks 
``` 
ansible-galaxy collection install -r /files/requirements.yml --force 
```
`--force` is required if you need to upgrade the collections to the latest available versions from the Galaxy server. 


## HPE OneView collection requirements
```
pip3 install -r ~/.ansible/collections/ansible_collections/hpe/oneview/requirements.txt
```

## VMware collection requirements
```
pip3 install --upgrade pip setuptools
pip3 install --upgrade git+https://github.com/vmware/vsphere-automation-sdk-python.git
pip3 install -r ~/.ansible/collections/ansible_collections/community/vmware/requirements.txt
pip3 install requests #(not sure if it is not part of the third party libraries)
```

## Windows collection requirements
```
pip3 install pywinrm
```
## Installation of json_query filter used in the playbooks
```
pip3 install jmespath
```
## Community.general.hpilo_boot requirement
```
pip3 install python-hpilo
```
## ngnix web service
ngnix is used to host the OS ISOs from which provisioned servers will boot using iLO virtual media.
```
yum install nginx
systemctl enable nginx
systemctl start nginx
firewall-cmd --permanent --add-service=http
firewall-cmd --reload
``` 

If you have a `ModuleNotFoundError: No module named 'six'` error, run the following command:
```
cp /usr/local/lib/python3.6/site-packages/six.py /usr/lib/python3.6/site-packages/
```

## Enabling ngnix directory browsing
```
sed -i  "0,/location \/ {/s//location \/ {\n        autoindex on;/" /etc/nginx/nginx.conf
systemctl restart nginx
```
