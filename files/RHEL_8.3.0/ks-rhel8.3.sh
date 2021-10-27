#version=RHEL8.3

# Use CDROM installation media
cdrom

# Network information
network --bootproto=static --device=team0 --gateway={{gateway}} --ip={{host_management_ip}} --nameserver={{nameserver}} --netmask={{netmask}} --activate --teamslaves="ens3f0,ens3f1" --teamconfig='{"runner": {"name": "activebackup"}}'


repo --name "AppStream" --baseurl=file:///run/install/repo/AppStream/
repo --name "BaseOS"    --baseurl=file:///run/install/repo/BaseOS/
repo --name="RHEL-8.3_baseos" --baseurl={{RHEL_baseos}} --noverifyssl
repo --name="RHEL-8.3_appstream" --baseurl={{RHEL_appstream}} --noverifyssl

# Reboot after installation
reboot

# Use text mode install
text

# Keyboard layouts
keyboard --xlayouts='us'

# System language
lang en_US.UTF-8

# Installation logging level
logging --level=info

# Root password - use 'opennssl passwd -6'
rootpw --iscrypted $6$kpUk9Sq7Yp/uVzcl$f9/0xR2oC/5DierkhdzDqiYex47nehfHQwxYOklxcU5.5MAXB7VeiEP2rrVmCw4CH4LqLK0AuR3cmeX1tqTE30

# System authorization information
authselect --enableshadow --passalgo=sha512

# SELinux configuration
selinux --disabled

# Run the Setup Agent on first boot
firstboot --disable

# Do not configure the X Window System
skipx

# System services
services --disabled="kdump,rpcbind,sendmail,postfix,chronyd"

# System timezone
timezone Europe/Paris --isUtc

# Create additional repo during installation - REMOVED FROM HERE AS DO NOT OFFER THE NO GPGCHECK OPTION - MOVED TO %POST
#repo --install --name="RHEL-8.3_baseos" --baseurl={{RHEL_baseos}} --noverifyssl
#repo --install --name="RHEL-8.3_appstream" --baseurl={{RHEL_appstream}} --noverifyssl


# Include the partitioning logic from the %pre section. 
# Required to replace the $BOOTDRIVE variable with its value for the drive selection and partitionning
%include /tmp/part-include


# pre section
%pre --log=/tmp/kickstart_pre.log

echo "Currently mounted partitions"
df -Th

echo "=============================="
echo "Available memory"
free -m

# Select the first drive that is the closest to SIZE, the size of the boot disk defined in the Server Profile

echo "Detecting boot drive for OS installation..."
SIZE={{size}}
BOOTDRIVE=""
MINDELTA=100

for DEV in /sys/block/s*; do
    if [[ -d $DEV && `cat $DEV/size` -ne 0  ]]; then
        #echo $DEV
        DISKSIZE=`cat $DEV/size`
        GB=$(($DISKSIZE/2**21))
        #echo "size $GB"
        DELTA=$(( $GB - $SIZE ))
        if [ "$DELTA" -lt 0 ]; then 
            DELTA=$((-DELTA))
        fi
                
        if [ $DELTA -lt $MINDELTA ]; then
            MINDELTA=$DELTA
            DRIVE=`echo $DEV | awk '{ print substr ($0, 12 ) }'`
        fi 
    echo "Diff is $DELTA with `echo $DEV | awk '{ print substr ($0, 12 ) }'`: $GB GB"
    fi

done

# Collecting multipath device name tied to the drive found
BOOTDRIVE=`lsblk -nl -o NAME /dev/$DRIVE  | sed -n '2 p'`

echo "BOOTDRIVE detected is $BOOTDRIVE"

cat << EOF >> /tmp/part-include
    # Clear the Master Boot Record
    zerombr
    # Disk Partition clearing information
    clearpart --all --initlabel --drives=$BOOTDRIVE

    # System bootloader configuration
    bootloader --append="rhgb novga console=ttyS0,115200 console=tty0 panic=1" --location=mbr --boot-drive=$BOOTDRIVE
    #--driveorder="sda" --boot-drive=sda
    # --driveorder=$BOOTDRIVE

    # Disk partitioning information
    autopart --type=lvm
EOF

echo "=============================="
echo "Kickstart pre install script completed at: `date`"

%end



%packages
@^server-product-environment
@system-tools
kexec-tools
python36
%end




%addon com_redhat_kdump --enable --reserve-mb='auto'

%end


%anaconda
pwpolicy root --minlen=6 --minquality=1 --notstrict --nochanges --notempty
pwpolicy user --minlen=6 --minquality=1 --notstrict --nochanges --emptyok
pwpolicy luks --minlen=6 --minquality=1 --notstrict --nochanges --notempty
%end


# 
%post --nochroot --log=/mnt/sysimage/var/log/kickstart_post_nochroot.log

echo "Copying %pre stage log files in /var/log folder"
/usr/bin/cp -rv /tmp/kickstart_pre.log /mnt/sysimage/var/log/
echo "=============================="
echo "Currently mounted partitions"
df -Th

# Set up the yum repositories for RHEL.
echo "Adding repos BaseOS and AppStream from web server"

configure_yum_repos()
{
# Enable internal RHEL repos (baseOS + appstream).
cat >> /mnt/sysimage/etc/yum.repos.d/rhel_web_repo.repo << RHEL
[RHEL-8.3_baseos]
name=RHEL-8.3_baseos
baseurl={{RHEL_baseos}}
enabled=1
gpgcheck=0
sslverify=0
[RHEL-8.3_appstream]
name=RHEL-8.3_appstream
baseurl={{RHEL_appstream}}
enabled=1
gpgcheck=0
sslverify=0
RHEL
}

configure_yum_repos

echo "Renaming host"
hostnamectl set-hostname {{inventory_hostname}}
hostnamectl --pretty set-hostname {{inventory_hostname}}
cp /etc/hostname /mnt/sysimage/etc/hostname
cp /etc/machine-info /mnt/sysimage/etc/machine-info

%end

%post --interpreter=/bin/bash --log=/var/log/kickstart_post.log

echo "Installing Ansible SSH public key"
mkdir -m0700 /root/.ssh/
cat <<EOF >/root/.ssh/authorized_keys
{{ansible_ssh_public_key}}
EOF
chmod 0600 /root/.ssh/authorized_keys
%end