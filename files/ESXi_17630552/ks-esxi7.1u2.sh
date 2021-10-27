vmaccepteula
rootpw  {{root_password}}
%include /tmp/DiskConfig
network --device=vmnic0 --bootproto=static --addvmportgroup=1 --ip={{host_management_ip}} --netmask={{netmask}} --gateway={{gateway}} --nameserver={{nameserver}} --hostname={{inventory_hostname}}   
reboot     
%pre --interpreter=busybox
# Finding boot volume for the OS installation
# Using minimum size difference with Server Profile size to identify the disk
SIZE={{size}}
MINDELTA=100
DRIVESIZE=""
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