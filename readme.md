# HPE Synergy Bare metal provisioning

Ansible project to automatically provision bare metal HPE Synergy servers.

The provisioning is performed automatically using kickstart files, autogenerated ISO files and HPE OneView Server Profile Templates.

## Use case

The different playbooks can be used to provision 3 type of OS:
- Red Hat Enterprise Linux or equivalent
- vSphere ESXi 6.7 and 7
- Windows Server 2022 or equivalent (coming soon)

One playbook can provision one OS type on one or multiple servers as defined by the Ansible inventory file.

## Pre-requisites

- HPE Synergy frame configured and at least one unused compute module
- OneView Server Profile template defined for each desired OS
- Ansible controller node (see below for configuration) with a drive large enough to host the generated ISO files

## Ansible control node information:

- It runs Ansible 
- It is used as the staging destination for the preparation of the ISO file(s)
- It runs *nginx* web services to host the created and customized ISO files from which the bare metal servers will boot from using iLO virtual media.

## Configure Ansible control node: 

To configure the Ansible controller node, see [Ansible_control_node_requirements.md](https://github.com/jullienl/Synergy-baremetal/blob/master/files/Ansible_control_node_requirements.md) in `/files`

## Preparation

1. Update all variables located in `<Ansible_project_dir>/vars/`
  
2. Copy the desired OS ISO versions on a webserver defined by `{{ src_iso_url }}` and `{{ src_iso_file }}` 

3. Create a HPE Oneview Server Profile Template with required parameters for each OS type. 
   - Use 6 network connections:
      * 2 for management 
      * 2 for FCoE 
      * 2 for Production network set  

      
      >**Note**: ESXi playbook adds a second management NIC for vswitch0 and looks for unused NICs (usually vmnic 4 and 5) to create Distibuted switch for VM traffic. RHEL and Windows playbooks create a team using the first two management NICs   
         
   - For Storage, the playbooks look for the boot LUN corresponding to what is defined in the Server Profile so you can use any SAN volume configuration: 
      - One boot from SAN OS LUN volume (a local storage logical volume can also be used)
      - Optional: other shared/Private SAN volumes for vmfs datastore/cluster volumes can also be defined
   - For RHEL and Windows provisioning, HPE drivers are installed at the end so it is required to set a firmware baseline with `Firmware only` installation method.

## How to protect sensitive credentials

Vault files can be used to secure all passwords. To learn more, see https://docs.ansible.com/ansible/latest/user_guide/vault.html
  - To encrypt a var file: `ansible-vault create --vault-id @prompt vars/encrypted_credentials.yml`
  - To run a playbook with encrypted credentials: `ansible-playbook <playbook.yml> --ask-vault-pass` 
  
## Description of the playbooks

### RHEL_autodeploy_using_autogenerated_ISO.yml
This playbook performs for each inventory host the automated RHEL 8.3 Boot from SAN installation using a customized kickstart, the main steps are:
- Create a DNS record for the bare metal server
- Download the OS vendor ISO file from a webserver
- Mount the ISO and copy all OS vendor ISO files to a staging directory
- Modify Legacy bios and UEFI bootloaders for kickstart installation from CDROM
- Create a HPE OneView Server Profile from an existing Server Profile Template
- Capture information for the customization of the kickstart file: 
  - Server generation 
  - MAC of first management NIC 
  - LUN URI of the primary boot volume
  - Boot LUN size 
- Customize the kickstart file with %pre script to detect the Boot From SAN volume
- Generate a temporary ISO file 
- Power on and boot the inventory host from created ISO using iLO virtual media
- Delete all temporary files in the stagging location and the created ISO once custom installation is complete
- Start the deployment of the HPE drivers for RHEL
  - Install HPE iSUT and HPE AMS on the new provisioned server
  - Configure HPE iSUT for online installation of HPE drivers for RHEL using HPE OneView
  - Update the HPE OneView Server Profile to start the OS Drivers updates (and Firmware if necessary) using SUT
- Reboot the server for the HPE drivers/firmware activation

### RHEL_unprovision.yml
This playbook performs for each inventory host the automated un-provisioning of the RHEL OS:
- Power off the server
- Delete the HPE OneView Server Profile
- Remove the DNS record
- Remove the SSH key 

### ESXi_autodeploy_using_autogenerated_ISO.yml
This playbook performs for each inventory host the automated ESXi 7.0.2 Boot from SAN installation using a customized kickstart, the main steps are:
- Create a DNS record for the bare metal server
- Download the HPE ESXi Custom Image ISO file from a webserver
- Mount the ISO and copy all ESXi ISO files to a staging directory
- Modify Legacy bios and UEFI bootloaders for kickstart installation from CDROM
- Create a HPE OneView Server Profile from an existing Server Profile Template
- Capture information for the customization of the kickstart file: 
  - Server generation 
  - MAC of first management NIC 
  - LUN URI of the primary boot volume
  - Boot LUN size 
- Customize the kickstart file with %pre script to detect the Boot From SAN volume
- Generate a temporary ISO file 
- Power on and boot the inventory host from created ISO using iLO virtual media
- Delete all temporary files in the stagging location and the created ISO once custom installation is complete
- Add the ESXi host to the defined vcenter server
- Assign defined vSphere ESXi license to host
- Add vmnic1 to standard switch vSwitch0 for the management console
- Add vMotion Portgroup to standard switch vSwitch0
- Connect the host to the defined distributed switch using available vmnics
- Set the Power Management Policy to high-performance
- Enable SSH and Shell services

### ESXi_unprovision.yml
This playbook performs for each inventory host the automated un-provisioning of the ESXi OS:
- Take host to maintenance mode
- Remove the host from the defined distributed switch
- remove the host from the defined vCenter server 
- Power off the server
- Delete the HPE OneView Server Profile
- Remove the DNS record

## Built and tested with

The resources in this repository were tested with:
- Ansible control node running on CentOS 8.2: 
  - Ansible 2.9.25 - Python 3.6.8 - python-hpOneView 6.30
  - Community.general 3.8.0 
  - Community.windows 1.7.0 
  - Community.vmware 1.15.0
  - Ansible Collection for HPE OneView 6.30 
   
- HPE OneView 6.30 
- Synergy 480 Gen10 
- SSP 2021-05.03
 
- Provisioned OS tested successfully: 
  - RHEL-8.3.0-20201009.2-x86_64-dvd1.iso
  - VMware-ESXi-7.0.2-17630552-HPE-702.0.0.10.6.5.27-Mar2021-Synergy.iso

## Output sample of ESXi bare metal provisioning playbook 

```
ansible-playbook -i hosts ESXi_autodeploy_using_autogenerated_ISO.yml 

PLAY [Creating a DNS record for the bare metal ESXi server] **************************************************************************************************************************************

TASK [Adding "ESX-2-deploy" with "192.168.3.175" on "dc.lj.lab" in "lj.lab" DNS domain] **********************************************************************************************************
ok: [ESX-2-deploy -> dc.lj.lab]

PLAY [Performing an automated ESXi 7.0 U2 Boot from SAN installation on a Gen10 Synergy Module using a kickstart and a OneView Server Profile Template] ******************************************

TASK [Checking if HPE ESXi Custom ISO file exists on "ansible.lj.lab"] ***************************************************************************************************************************
ok: [ESX-2-deploy -> localhost]

TASK [Creating the directory "/opt/esxiisosrc" to host the ISO file on "ansible.lj.lab"] *********************************************************************************************************
ok: [ESX-2-deploy -> localhost]

TASK [Downloading file "VMware-ESXi-7.0.2-17630552-HPE-702.0.0.10.6.5.27-Mar2021-Synergy.iso" to "ansible.lj.lab" if not present] ****************************************************************
skipping: [ESX-2-deploy]

TASK [Checking if HPE ESXi Custom ISO file extraction is necessary on "ansible.lj.lab"] **********************************************************************************************************
ok: [ESX-2-deploy -> localhost]

TASK [Creating /mnt/ESX-2-deploy on "ansible.lj.lab" if it does not exist] ***********************************************************************************************************************
changed: [ESX-2-deploy -> localhost]

TASK [Creating /opt/baremetal/ESX-2-deploy/ on "ansible.lj.lab" if it does not exist] ************************************************************************************************************
changed: [ESX-2-deploy -> localhost]

TASK [Creating /opt/baremetal/temp/ESX-2-deploy/ on "ansible.lj.lab" if it does not exist] *******************************************************************************************************
changed: [ESX-2-deploy -> localhost]

TASK [Creating /opt/baremetal/temp/ESX-2-deploy/etc/vmware/weasel on "ansible.lj.lab" if it does not exist] **************************************************************************************
changed: [ESX-2-deploy -> localhost]

TASK [Mounting HPE ESXi Custom ISO and copying ISO files to /opt/baremetal/ESX-2-deploy/ on "ansible.lj.lab"] ************************************************************************************
changed: [ESX-2-deploy -> localhost]

TASK [Modifying legacy bios SYSLINUX bootloader for kickstart installation from CDROM] ***********************************************************************************************************
changed: [ESX-2-deploy -> localhost]

TASK [Modifying UEFI bootloader for kickstart installation from CDROM] ***************************************************************************************************************************
changed: [ESX-2-deploy -> localhost]

TASK [Creating Server Profile "ESX-2-deploy" from Server Profile Template "ESXi7 BFS"] ***********************************************************************************************************
changed: [ESX-2-deploy -> localhost]

TASK [Capturing information for the customization of the kickstart file [server generation - MAC of first management NIC - LUN uri of the primary boot volume]] **********************************
ok: [ESX-2-deploy]

TASK [Showing the result of the Server Profile creation task] ************************************************************************************************************************************
ok: [ESX-2-deploy] => {
    "msg": "Hardware selected: Frame4, bay 4 - Result: Server Profile created."
}

TASK [Collecting volumes information] ************************************************************************************************************************************************************
ok: [ESX-2-deploy -> localhost]

TASK [Capturing boot LUN size defined in the Server Profile to ensure that ESXi will be installed on this disk using the kickstart file] *********************************************************
ok: [ESX-2-deploy]

TASK [Creating kickstart file with %pre script to detect the "20GB" Boot From SAN volume] ********************************************************************************************************
changed: [ESX-2-deploy -> localhost]

TASK [Preparing ks.cfg kickstart file to make the new ISO] ***************************************************************************************************************************************
changed: [ESX-2-deploy -> localhost]

TASK [Creating the ks.tgz kickstart file to make the new ISO] ************************************************************************************************************************************
changed: [ESX-2-deploy -> localhost]

TASK [Copying new ks.tgz to /opt/baremetal/ESX-2-deploy/] ****************************************************************************************************************************************
changed: [ESX-2-deploy -> localhost]

TASK [Creating customized bootable ISO] **********************************************************************************************************************************************************
changed: [ESX-2-deploy -> localhost]

TASK [Creating /usr/share/nginx/html/isos/ on "ansible.lj.lab" if it does not exist] *************************************************************************************************************
ok: [ESX-2-deploy -> localhost]

TASK [Moving created ISO to the nginx default html folder of "ansible.lj.lab"] *******************************************************************************************************************
changed: [ESX-2-deploy -> localhost]

TASK [Powering on and booting "Frame4, bay 4" from created ISO using iLO Virtual Media] **********************************************************************************************************
changed: [ESX-2-deploy -> localhost]

TASK [Waiting for ESX installation to complete - waiting for "192.168.3.175" to respond...] ******************************************************************************************************
ok: [ESX-2-deploy -> localhost]

TASK [debug] *************************************************************************************************************************************************************************************
ok: [ESX-2-deploy] => {
    "msg": "ESX-2-deploy installation took 14 minutes"
}

TASK [Wait a little longer so that the ESX host is truly ready to be added to the vcenter] *******************************************************************************************************
ok: [ESX-2-deploy -> localhost]

TASK [Deleting all related files from staging location and web server] ***************************************************************************************************************************
changed: [ESX-2-deploy -> localhost]

TASK [Adding ESXi host "esx-2-deploy.lj.lab" to vCenter "vcenter.lj.lab"] ************************************************************************************************************************
changed: [ESX-2-deploy -> localhost]

TASK [Assigning ESXi license to Host] ************************************************************************************************************************************************************
changed: [ESX-2-deploy -> localhost]

TASK [Adding vmnic1 to standard switch vSwitch0] *************************************************************************************************************************************************
changed: [ESX-2-deploy -> localhost]

TASK [Adding vMotion Portgroup to standard switch vSwitch0] **************************************************************************************************************************************
changed: [ESX-2-deploy -> localhost]

TASK [Gathering facts about vmnics] **************************************************************************************************************************************************************
ok: [ESX-2-deploy -> localhost]

TASK [Capturing available vmnics for the distributed switch creation] ****************************************************************************************************************************
ok: [ESX-2-deploy]

TASK [Connecting host to "DSwitch-VC100G" distributed switch] ************************************************************************************************************************************
changed: [ESX-2-deploy -> localhost]

TASK [Adding vmkernel mk1 port to "DSwitch-VC100G" distributed Switch] ***************************************************************************************************************************
changed: [ESX-2-deploy -> localhost]

TASK [Changing Advanced Settings with Core Dump Warning Disable] *********************************************************************************************************************************
changed: [ESX-2-deploy -> localhost]

TASK [Setting the Power Management Policy to high-performance] ***********************************************************************************************************************************
changed: [ESX-2-deploy -> localhost]

TASK [Configuring NTP servers] *******************************************************************************************************************************************************************
[WARNING]: Found internal 'results' key in module return, renamed to 'ansible_module_results'.
changed: [ESX-2-deploy -> localhost]

TASK [Starting NTP Service and set to start at boot.] ********************************************************************************************************************************************
[WARNING]: Found internal 'results' key in module return, renamed to 'ansible_module_results'.
[WARNING]: The value True (type bool) in a string field was converted to 'True' (type string). If this does not look like what you expect, quote the entire value to ensure it does not change.
changed: [ESX-2-deploy -> localhost]

TASK [Starting ESXi Shell Service and setting to enable at boot . . .] ***************************************************************************************************************************
[WARNING]: Found internal 'results' key in module return, renamed to 'ansible_module_results'.
changed: [ESX-2-deploy -> localhost]

TASK [Starting SSH Service and setting to enable at boot.] ***************************************************************************************************************************************
[WARNING]: Found internal 'results' key in module return, renamed to 'ansible_module_results'.
changed: [ESX-2-deploy -> localhost]

TASK [Displaying install completed message] ******************************************************************************************************************************************************
ok: [ESX-2-deploy] => {
    "msg": [
        "ESX-2-deploy.lj.lab Installation completed !",
        "ESXi is configured and running. It has been added to the vCenter cluster 'Synergy Frame4'."
    ]
}

PLAY RECAP ***************************************************************************************************************************************************************************************
ESX-2-deploy               : ok=43   changed=28   unreachable=0    failed=0    skipped=1    rescued=0    ignored=0  
```


## Output sample of ESXi bare metal unprovisioning playbook 

```
ansible-playbook -i hosts ESXi_unprovision.yml 

PLAY [Deleting a provisioned ESXi compute module] ************************************************************************************************************************************************

TASK [Taking "esx-2-deploy.lj.lab" to maintenance mode] ******************************************************************************************************************************************
changed: [ESX-2-deploy -> localhost]

TASK [Removing vmkernel mk1 port from "DSwitch-VC100G" distributed Switch] ***********************************************************************************************************************
changed: [ESX-2-deploy -> localhost]

TASK [Gathering facts about vmnics] **************************************************************************************************************************************************************
ok: [ESX-2-deploy -> localhost]

TASK [Capturing available vmnics for the distributed switch creation] ****************************************************************************************************************************
ok: [ESX-2-deploy]

TASK [Removing host from "DSwitch-VC100G" distributed Switch] ************************************************************************************************************************************
changed: [ESX-2-deploy -> localhost]

TASK [Removing ESXi host "esx-2-deploy.lj.lab" from vCenter "vcenter.lj.lab"] ********************************************************************************************************************
changed: [ESX-2-deploy -> localhost]

TASK [Getting server profile "ESX-2-deploy" information] *****************************************************************************************************************************************
ok: [ESX-2-deploy -> localhost]

TASK [Powering off server hardware "Frame4, bay 4"] **********************************************************************************************************************************************
changed: [ESX-2-deploy -> localhost]

TASK [Deleting server profile "ESX-2-deploy"] ****************************************************************************************************************************************************
changed: [ESX-2-deploy -> localhost]

TASK [Result of the task to delete the server profile] *******************************************************************************************************************************************
ok: [ESX-2-deploy] => {
    "msg": "Deleted profile"
}

PLAY [Removing the DNS record for "{{ inventory_hostname }}"] ************************************************************************************************************************************

TASK [Removing "192.168.3.172"" from "dc.lj.lab"] ************************************************************************************************************************************************
ok: [RHEL-deploy -> dc.lj.lab]

PLAY RECAP ***************************************************************************************************************************************************************************************
ESX-2-deploy               : ok=10   changed=6    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
RHEL-deploy                : ok=1    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
```


## Output sample of RHEL bare metal provisioning playbook 

```
ansible-playbook -i hosts RHEL_autodeploy_using_autogenerated_ISO.yml 

PLAY [Creating a DNS record for the bare metal RHEL server] **************************************************************************************************************************************

TASK [Adding "RHEL-deploy" with "192.168.3.172" on "dc.lj.lab" in "lj.lab" DNS domain] ***********************************************************************************************************
changed: [RHEL-deploy -> dc.lj.lab]

PLAY [Performing an automated RHEL 8.3 Boot from SAN installation on a Gen10 Synergy Module using a kickstart and a OneView Server Profile Template] *********************************************

TASK [Checking if RHEL ISO file exists on "ansible.lj.lab"] **************************************************************************************************************************************
ok: [RHEL-deploy -> localhost]

TASK [Creating the directory "/opt/rhelisosrc" to host the ISO file on "ansible.lj.lab"] *********************************************************************************************************
ok: [RHEL-deploy -> localhost]

TASK [Downloading file "RHEL-8.3-minimum.iso" to "ansible.lj.lab" if not present] ****************************************************************************************************************
skipping: [RHEL-deploy]

TASK [Collecting ISO label (can be required for some booltloader modifications)] *****************************************************************************************************************
changed: [RHEL-deploy -> localhost]

TASK [set_fact] **********************************************************************************************************************************************************************************
ok: [RHEL-deploy]

TASK [Checking if RHEL ISO file extraction is necessary on "RHEL-deploy"] ************************************************************************************************************************
ok: [RHEL-deploy -> localhost]

TASK [Creating /mnt/RHEL-deploy on "ansible.lj.lab" if it does not exist] ************************************************************************************************************************
changed: [RHEL-deploy -> localhost]

TASK [Creating /opt/baremetal/RHEL-deploy/ on "ansible.lj.lab" if it does not exist] *************************************************************************************************************
changed: [RHEL-deploy -> localhost]

TASK [Mounting RHEL ISO and copying ISO files to /opt/baremetal/RHEL-deploy/ on "ansible.lj.lab"] ************************************************************************************************
changed: [RHEL-deploy -> localhost]

TASK [Modifying legacy bios SYSLINUX bootloader for kickstart installation from CDROM] ***********************************************************************************************************
changed: [RHEL-deploy -> localhost]

TASK [Modifying UEFI bootloader for kickstart installation from CDROM] ***************************************************************************************************************************
changed: [RHEL-deploy -> localhost]

TASK [Creating Server Profile "RHEL-deploy" from Server Profile Template "RHEL BFS"] *************************************************************************************************************
changed: [RHEL-deploy -> localhost]

TASK [Capturing information for the customization of the kickstart file [server generation - MAC of first management NIC - LUN uri of the primary boot volume]] **********************************
ok: [RHEL-deploy]

TASK [Showing the result of the Server Profile creation task] ************************************************************************************************************************************
ok: [RHEL-deploy] => {
    "msg": "Hardware selected: Frame4, bay 4 - Result: Server Profile created."
}

TASK [Collecting volumes information] ************************************************************************************************************************************************************
ok: [RHEL-deploy -> localhost]

TASK [Capturing boot LUN size defined in the Server Profile to ensure that OS will be installed on this disk using the kickstart file] ***********************************************************
ok: [RHEL-deploy]

TASK [Creating kickstart file with %pre script to detect the "50GB" Boot From SAN volume] ********************************************************************************************************
changed: [RHEL-deploy -> localhost]

TASK [Creating customized bootable ISO] **********************************************************************************************************************************************************
changed: [RHEL-deploy -> localhost]

TASK [Implanting MD5 checksum into the ISO to make it bootable] **********************************************************************************************************************************
changed: [RHEL-deploy -> localhost]

TASK [Creating /usr/share/nginx/html/isos/ on "ansible.lj.lab" if it does not exist] *************************************************************************************************************
ok: [RHEL-deploy -> localhost]

TASK [Moving created ISO to the nginx default html folder of "ansible.lj.lab"] *******************************************************************************************************************
changed: [RHEL-deploy -> localhost]

TASK [Powering on and booting "Frame4, bay 4" from created ISO using iLO Virtual Media] **********************************************************************************************************
changed: [RHEL-deploy -> localhost]

TASK [Waiting for RHEL installation to complete - Waiting for "192.168.3.172" to respond...] *****************************************************************************************************
ok: [RHEL-deploy -> localhost]

TASK [debug] *************************************************************************************************************************************************************************************
ok: [RHEL-deploy] => {
    "msg": "RHEL-deploy installation took 13 minutes"
}

TASK [Deleting all temporary files in the stagging location on "ansible.lj.lab"] *****************************************************************************************************************
changed: [RHEL-deploy -> localhost]

TASK [Deleting created ISO file in the web server directory on "ansible.lj.lab"] *****************************************************************************************************************
changed: [RHEL-deploy -> localhost]

TASK [Unmounting original ISO file on "ansible.lj.lab"] ******************************************************************************************************************************************
changed: [RHEL-deploy -> localhost]

TASK [Copying HPE iSUT rpm file to RHEL-deploy] **************************************************************************************************************************************************
changed: [RHEL-deploy]

TASK [Copying HPE AMS rpm file to RHEL-deploy] ***************************************************************************************************************************************************
changed: [RHEL-deploy]

TASK [Installing iSUT] ***************************************************************************************************************************************************************************
changed: [RHEL-deploy]

TASK [Installing AMS] ****************************************************************************************************************************************************************************
changed: [RHEL-deploy]

TASK [Waiting for iSUT installation to complete] *************************************************************************************************************************************************
ok: [RHEL-deploy -> localhost]

TASK [Configuring iSUT mode to allow OS driver updates via HPE OneView Server Profile] ***********************************************************************************************************
changed: [RHEL-deploy]

TASK [debug] *************************************************************************************************************************************************************************************
ok: [RHEL-deploy] => {
    "msg": "Set Mode: autodeploy\nService will be registered and started\nSUT Service started successfully\nRegistration successful"
}

TASK [Updating Server Profile to enable Firmware and OS Drivers using SUT] ***********************************************************************************************************************
changed: [RHEL-deploy -> localhost]

TASK [debug] *************************************************************************************************************************************************************************************
ok: [RHEL-deploy] => {
    "msg": "Server profile updated"
}

TASK [Monitoring SUT status for 'reboot the system' message] *************************************************************************************************************************************
FAILED - RETRYING: Monitoring SUT status for 'reboot the system' message (50 retries left).
FAILED - RETRYING: Monitoring SUT status for 'reboot the system' message (49 retries left).
FAILED - RETRYING: Monitoring SUT status for 'reboot the system' message (48 retries left).
FAILED - RETRYING: Monitoring SUT status for 'reboot the system' message (47 retries left).
FAILED - RETRYING: Monitoring SUT status for 'reboot the system' message (46 retries left).
FAILED - RETRYING: Monitoring SUT status for 'reboot the system' message (45 retries left).
FAILED - RETRYING: Monitoring SUT status for 'reboot the system' message (44 retries left).
FAILED - RETRYING: Monitoring SUT status for 'reboot the system' message (43 retries left).
FAILED - RETRYING: Monitoring SUT status for 'reboot the system' message (42 retries left).
changed: [RHEL-deploy]

TASK [debug] *************************************************************************************************************************************************************************************
ok: [RHEL-deploy] => {
    "msg": "Reboot the system or execute -activate command to complete the system reboot."
}

TASK [Rebooting host for the HPE drivers/firmware activation and waiting for it to restart] ******************************************************************************************************
changed: [RHEL-deploy]

TASK [Displaying install completed message] ******************************************************************************************************************************************************
ok: [RHEL-deploy] => {
    "msg": [
        "RHEL-deploy.lj.lab Installation completed !",
        "OS is configured and running with HPE OS drivers."
    ]
}

PLAY RECAP ***************************************************************************************************************************************************************************************
RHEL-deploy                : ok=40   changed=24   unreachable=0    failed=0    skipped=1    rescued=0    ignored=0   
```

## Output sample of RHEL bare metal unprovisioning playbook 
```
ansible-playbook -i hosts RHEL_unprovision.yml 

PLAY [Deleting provisioned RHEL compute module(s)] ***********************************************************************************************************************************************

TASK [Getting server profile "RHEL-deploy" information] ******************************************************************************************************************************************
ok: [RHEL-deploy -> localhost]

TASK [Powering off server hardware "Frame4, bay 4"] **********************************************************************************************************************************************
changed: [RHEL-deploy -> localhost]

TASK [Deleting server profile "RHEL-deploy"] *****************************************************************************************************************************************************
changed: [RHEL-deploy -> localhost]

TASK [Result of the task to delete the server profile] *******************************************************************************************************************************************
ok: [RHEL-deploy] => {
    "msg": "Deleted profile"
}

TASK [Removing RHEL-deploy SSH key] **************************************************************************************************************************************************************
changed: [RHEL-deploy -> localhost]

PLAY [Removing the DNS record for "{{ inventory_hostname }}"] ************************************************************************************************************************************

TASK [Removing "192.168.3.172"" from "dc.lj.lab"] ************************************************************************************************************************************************
changed: [RHEL-deploy -> dc.lj.lab]

PLAY RECAP ***************************************************************************************************************************************************************************************
RHEL-deploy                : ok=6    changed=4    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0  
```


## Thank you

Thank you to bryansullins for his inspiring work for [baremetalesxi](https://github.com/bryansullins/baremetalesxi).

## License

This project is licensed under the MIT License - see the LICENSE file for details