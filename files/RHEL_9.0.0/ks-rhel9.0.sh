#version=RHEL9.0


# Installation mode
text
# graphical


# To be used with DVD ISO (named rhel-xxx-dvd.iso)
# (contains the installer as well as a set of all packages)
# cdrom

# To be used with Boot ISO (named rhel-xxx-boot.iso)
# (contains only the installer, but not any installable packages)
url --url={{RHEL_repo_url}} --noverifyssl
repo --name=BaseOS --baseurl={{RHEL_repo_url}}/BaseOS --noverifyssl


# Network configuration 
%include /tmp/network.ks
 
%pre --interpreter=/usr/bin/bash --log=/tmp/kickstart_network_configuration.log

echo "Network configuration: /tmp/network.ks or /var/log/network.ks"

nicbonding="{{enable_nic_bonding}}"

ip addr | grep -m 2 -i "state up" | awk '{ print $2 }' > /tmp/interface
# Remove colon
sed -i 's/:/\ /g' /tmp/interface
# Merge the lines into a single line separated by a comma then remove spaces
interface=`cat /tmp/interface | paste -sd ',' | tr -d ' '`

if [[ "$nicbonding" == "true" ]]; then
    # With bonding:
    #  Create a team with the first two connected nics if any, 
    #  If only one nic is connected, use only one nic in the team
    echo "Network interfaces found: $interface"
    echo "network --device=team0 --bondslaves=$interface --bootproto=static --ip={{os_ip_address}} --activate --onboot yes --noipv6 --netmask={{netmask}} --gateway={{gateway}} --nameserver={{nameserver}} --bondopts=mode=active-backup" >/tmp/network.ks

else
    # With no bonding:
    #  Take only the first nic found
    firstnic=$(echo "$interface" | cut -d ',' -f1)
    echo "Network interface found: $firstnic"
    echo "network --bootproto=static --ip={{os_ip_address}} --activate --onboot yes --noipv6 --netmask={{netmask}} --gateway={{gateway}} --nameserver={{nameserver}} --device=$firstnic" >/tmp/network.ks
fi

echo "Command set: $(</tmp/network.ks)" 
%end


# Firewall configuration
firewall --enabled --service ssh

# Reboot after installation
reboot

# Keyboard layouts
keyboard --xlayouts={{keyboard}}

# System language
lang {{language}}

# Installation logging level
# logging --level=info

# Root password 
rootpw --iscrypted {{encrypted_root_password}}

# System authorization information
authselect --enableshadow --passalgo=sha512

# SELinux configuration
# The default SELinux policy is enforcing

# Run the Setup Agent on first boot
firstboot --enable

# Do not configure the X Window System
skipx

# System services - Enable time synchronisation daemon 
services --enabled="chronyd"

# System timezone
timezone --utc {{timezone}} 
timesource --ntp-server {{ntp_server}} 




# Include the partitioning logic from the %pre section. 
# Required to replace the $BOOTDRIVE variable with its value for the drive selection and partitionning
%include /tmp/part-include

# pre section
%pre --log=/tmp/kickstart_pre.log

# Select the first drive that is the closest to SIZE, the size of the boot disk defined in the Server Profile
SIZEinGB={{boot_lun_size}}
# SIZEinGB=50

size_bytes=$((SIZEinGB * 1073741824))

# if SIZE exists then use boot from SAN volume for the OS installation
if [ "$SIZE" != "undefined" ]; then 
    echo "Detecting boot drive for OS installation..."

    # Get the first disk from the disk list with the size defined in the server profile for the boot lun:
    disk=`lsblk -nblo NAME,SIZE | awk '$2 == "'"$size_bytes"'" {print $1}' | head -n 1` # => usually returns sdd
    # disk=`lsblk -nblo NAME,SIZE | awk '$2 == "'"$size_bytes"'" {print $1}' | awk '$1 ~ "mpath" {print $1}' | head -n 1` # => usually returns mpatha  

    # Get WWID of the multipath disk to make sure the correct disk is used to deploy the OS
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

# bootloader --append="rhgb novga console=ttyS0,115200 console=tty0 panic=1" --location=mbr --boot-drive=$BOOTDRIVE
bootloader --append="rhgb quiet crashkernel=auto"


%packages
@^minimal-environment
# @system-tools
# kexec-tools
# python36
%end



# ENABLE EMERGENCY KERNEL DUMPS FOR DEBUGGING
%addon com_redhat_kdump --enable --reserve-mb='auto'
%end



###############################################################################
# Post-Installation Scripts (nochroot)
###############################################################################

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
# Enable internal RHEL repos (BaseOS + Appstream).
    cat >> /mnt/sysimage/etc/yum.repos.d/rhel_web_repo.repo << EOF
[RHEL-9.0_baseos]
name=RHEL-9.0_baseos
baseurl={{RHEL_repo_url}}/BaseOS
enabled=1
gpgcheck=1
gpgkey={{RHEL_repo_url}}/RPM-GPG-KEY-redhat-release
sslverify=0

[RHEL-9.0_appstream]
name=RHEL-9.0_appstream
baseurl={{RHEL_repo_url}}/AppStream
enabled=1
gpgcheck=1
gpgkey={{RHEL_repo_url}}/RPM-GPG-KEY-redhat-release
sslverify=0
EOF

      # Enable the EPEL
  rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm

}

configure_yum_repos

echo "Renaming host"
hostnamectl set-hostname {{inventory_hostname}}.{{domain}}
hostnamectl --pretty set-hostname {{inventory_hostname}}
cp /etc/hostname /mnt/sysimage/etc/hostname
cp /etc/machine-info /mnt/sysimage/etc/machine-info

%end


###############################################################################
# Post-Installation Scripts
###############################################################################

%post --interpreter=/bin/bash --log=/var/log/kickstart_post.log

echo "Installing Ansible SSH public key"
mkdir -m0700 /root/.ssh/
cat <<EOF >/root/.ssh/authorized_keys
{{ansible_ssh_public_key}}
EOF
chmod 0600 /root/.ssh/authorized_keys
%end












