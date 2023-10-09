vmaccepteula
rootpw  {{root_password}}
%include /tmp/DiskConfig
network --device=vmnic0 --bootproto=static --addvmportgroup=1 --ip={{host_management_ip}} --netmask={{netmask}} --gateway={{gateway}} --nameserver={{nameserver}} --hostname={{inventory_hostname}}   
reboot   


%pre --interpreter=busybox
# Finding boot volume for the OS installation
# Using minimum size difference with Server Profile size to identify the disk
SIZE={{boot_lun_size}}
MINDELTA=100
DRIVESIZE=""

# if SIZE exists then use boot from SAN volume for the OS installation
if [ "$SIZE" != "undefined" ]; then 
    for DISK in `ls /vmfs/devices/disks/n* | grep -v ":"`; do
        VML=$(echo $DISK | awk '{ print substr ($0, 21 ) }')
        VSIZE=$(localcli storage core device list -d $VML  | sed -n 5p |  awk '{ print substr ($0, 10 ) }')
        # If $VSIZE is not null and not equal to zero
        if [[ -n $VSIZE && $VSIZE -ne 0 ]]; then
            DETAIL=$(esxcli storage core device list -d $VML)
            GB=$(($VSIZE/1024))
            echo "Size = $GB GB"
            DELTA=$(( $GB - $SIZE ))
            if [ "$DELTA" -lt 0 ]; then
                DELTA=$((-DELTA))
            fi
            if [ $DELTA -lt $MINDELTA ]; then
                MINDELTA=$DELTA
                DRIVE=$DISK
                DRIVESIZE=$GB
            fi
            echo "Diff is $DELTA GB with `echo $DEV | awk '{ print substr ($0, 12 ) }'` $GB GB"
            echo "Matching Drive: $DRIVESIZE GB"
        fi
    done
    # Collecting vmfs volume name of the drive found
    echo "BOOTDRIVE is $DRIVE with $DRIVESIZE GB"
    echo "clearpart --drives=$DRIVE --overwritevmfs">/tmp/DiskConfig
    echo "install --disk=$DRIVE --overwritevmfs --novmfsondisk">>/tmp/DiskConfig
else
# if SIZE does not exist then use local disk for the OS installation
    echo "BOOTDRIVE is LOCAL"
    echo "clearpart --firstdisk=local --overwritevmfs">/tmp/DiskConfig
    echo "install --firstdisk=local --overwritevmfs --novmfsondisk">>/tmp/DiskConfig
fi    



%firstboot --interpreter=busybox

# Hostname and domain settings
esxcli system hostname set --host="{{inventory_hostname}}"
esxcli system hostname set --fqdn="{{inventory_hostname}}.{{domain}}"
esxcli network ip dns search add --domain="{{domain}}"

# Adding Ansible control node SSH public key to host authorized_keys 
echo "Installing Ansible SSH public key"
cat <<EOF >/etc/ssh/keys-root/authorized_keys
{{ansible_ssh_public_key}}
EOF
