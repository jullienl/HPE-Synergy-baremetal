#version=RHEL8.3

# Use CDROM installation media
cdrom

# Network information
network --bootproto=static --device=team0 --gateway={{gateway}} --ip={{os_ip_address}} --nameserver={{nameserver}} --netmask={{netmask}} --activate --teamslaves="ens3f0,ens3f1" --teamconfig='{"runner": {"name": "activebackup"}}'


repo --name "AppStream" --baseurl=file:///run/install/repo/AppStream/
repo --name "BaseOS"    --baseurl=file:///run/install/repo/BaseOS/
repo --name="RHEL-8.3_baseos" --baseurl={{RHEL_baseos}} --noverifyssl
repo --name="RHEL-8.3_appstream" --baseurl={{RHEL_appstream}} --noverifyssl

# Reboot after installation
reboot

# Use text mode install
text

# Keyboard layouts
keyboard --xlayouts={{keyboard}}

# System language
lang {{language}}

# Installation logging level
logging --level=info

# Root password - use 'opennssl passwd -6'
rootpw --iscrypted {{encrypted_root_password}}

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
timezone {{timezone}} --isUtc --ntpservers={{ntp_servers}}

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


SIZEinGB={{boot_lun_size}}
# SIZEinGB=50

size_bytes=$((SIZEinGB * 1073741824))

# if SIZE exists then use boot from SAN volume for the OS installation
if [ "$SIZE" != "undefined" ]; then 
    echo "Detecting boot drive for OS installation..."

    # Get the first disk from the disk list with the size defined in the server profile for the boot lun:
    disk=`lsblk -nblo NAME,SIZE | awk '$2 == "'"$size_bytes"'" {print $1}' | head -n 1` # => usually returns sdd
    # disk=`lsblk -nblo NAME,SIZE | awk '$2 == "'"$size_bytes"'" {print $1}' | awk '$1 ~ "mpath" {print $1}' | head -n 1` # => returns mpatha  

    wwid=`/usr/lib/udev/scsi_id -g -u -d /dev/$disk`
  
    echo "BOOTDRIVE detected is $disk using symbolic link disk/by-id/dm-uuid-mpath-$wwid"

    # Disk partitioning information
    # To include a multipath device that does not use LVM:
    # ignoredisk --only-use=disk/by-id/dm-uuid-mpath-<WWID>
    # https://github.com/CentOS/8docs/blob/f910741c5db5a32508434598cd26b9379f4eab3d/modules/ROOT/partials/kickstart/ref_ignoredisk.adoc#L38

    # To set manual partitions, use the following example instead of autopart:
    # part /boot/efi --label=FIRMWARE --size=1024         --asprimary --fstype=efi --ondisk=disk/by-id/dm-uuid-mpath-$wwid
    # part /boot     --label=BOOT     --size=1024         --asprimary --fstype=ext4 --ondisk=disk/by-id/dm-uuid-mpath-$wwid
    # part pv.01     --label=VOLUMES  --size=1024  --grow --asprimary --ondisk=disk/by-id/dm-uuid-mpath-$wwid
    # volgroup system  pv.01
    # logvol /       --label=ROOT     --size=1024  --grow --vgname=system  --name=root --fstype=xfs 
    # logvol swap    --label=SWAP     --size=8192         --vgname=system  --name=swap 

    cat << EOF >> /tmp/part-include
    # Clear the Master Boot Record
    zerombr
    
    # Disk Partition clearing information
    clearpart --all --initlabel --drives=disk/by-id/dm-uuid-mpath-$wwid

    # System bootloader configuration
    bootloader --append="rhgb novga console=ttyS0,115200 console=tty0 panic=1" --location=mbr --boot-drive=disk/by-id/dm-uuid-mpath-$wwid
    
    # Disk partitioning information
    ignoredisk --only-use=disk/by-id/dm-uuid-mpath-$wwid
    autopart --type=lvm
EOF
else
# if SIZE does not exist then use local disk for the OS installation
    cat << EOF >> /tmp/part-include
        # Choose the disks to be used
        ignoredisk --only-use=sda
        
        # Clear the Master Boot Record
        zerombr
        
        # Disk Partition clearing information
        clearpart --all --initlabel --drives=sda

        # System bootloader configuration
        bootloader --append="rhgb novga console=ttyS0,115200 console=tty0 panic=1" --location=mbr --boot-drive=sda

        # Disk partitioning information
        autopart --type=lvm
EOF
fi


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
hostnamectl set-hostname {{inventory_hostname}}.{{domain}}
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