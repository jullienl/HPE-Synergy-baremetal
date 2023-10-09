# HPE Synergy bare metal provisioning

Ansible project for automatic provisioning of HPE Synergy bare metal servers, but note that this project can also be used for rackmount servers without major modifications.

Operating system provisioning (ESXi, RHEL and Windows server) is performed using kickstart/unattend files, automatically generated ISO files and HPE OneView server profile templates.

## Use case

The different playbooks can be used to provision 3 types of operating systems:

- Red Hat Enterprise Linux and equivalent
- VMware ESXi 6.7 and 7
- Windows Server 2022 and equivalent

One playbook can provision one OS type on one or multiple servers as defined by the Ansible inventory file.

## Built and tested with

The resources in this repository have been tested with Ansible control node running on a Rocky Linux 9.2 VM with:
  - Ansible core 2.15.4
  - Python 3.9.16
  - HPE OneView Python SDK 8.5.1
  - Ansible Collection for HPE OneView 8.5.1
  - Community.general 3.8.0
  - Community.windows 1.7.0
  - Community.vmware 1.15.0
  - HPE OneView 8.50
  - Synergy 480 Gen10/Gen10 Plus 
  - HPE Synergy Service Pack 2022.11.01

The GitHub CentOS8.2 branch provides the resources that were tested in 2021 on a CentOS 8.2 VM with:
  - Ansible core 2.9.25
  - Python 3.6.8
  - HPE OneView Python SDK 6.30
  - Ansible Collection for HPE OneView 6.30
  - Community.general 3.8.0
  - Community.windows 1.7.0
  - Community.vmware 1.15.0
  - HPE OneView 6.30
  - Synergy 480 Gen10 
  - HPE Synergy Service Pack 2021-05.03

The provisioned OS tested successfully are:
  - RHEL-8.3.0-20201009.2-x86_64-dvd1.iso  
  - rhel-baseos-9.0-x86_64-dvd.iso 
     > Note: Based on my experience, I encountered difficulties with the RHEL 9.x minimum image, specifically the rhel-baseos-9.0-x86_64-boot.iso (766MB) file. During the kickstart installation, it appeared to hang at the "Checking storage configuration" step. Therefore, I would suggest avoiding the use of RHEL 9.x minimum images due to this issue.
  - VMware-ESXi-7.0.2-17630552-HPE-702.0.0.10.6.5.27-Mar2021-Synergy.iso
  - VMware-ESXi-7.0.3-21930508-HPE-703.0.0.11.3.5.9-Aug2023-Synergy.iso
  - en-us_windows_server_version_2022_updated_october_2021_x64_dvd_b6e25591.iso


## Pre-requisites

- HPE Synergy frame configured and at least one unused Synergy 480 Gen10/Gen10 Plus compute module.
- OneView Server Profile Templates defined for each desired OS with a local storage boot drive or a boot from SAN storage volume (see below for configuration).
- OneView server profile templates must include the creation of an iLO local account. This account is required by the [community.general](https://galaxy.ansible.com/community/general) collection to manage an HPE iLO interface.
- Ansible control node (see below for configuration) with a hard disk large enough to host a copy of the ISO files, and temporarily the extraction of ISO(s) and generated ISO(s)  (500GB+ is recommended). 
- Windows DNS server configured to be managed by Ansible (see below for configuration).

## Ansible control node information

- It runs Ansible
- It can be a physical server or a Virtual Machine
- It is used as the staging destination for the preparation of the ISO file(s)
- It runs `nginx` web services to host the created and customized ISO files from which the bare metal servers will boot from using iLO virtual media.

## Configure Ansible control node

To configure the Ansible control node, see [Ansible_control_node_requirements.md](https://github.com/jullienl/HPE-Synergy-baremetal/blob/master/files/Ansible_control_node_requirements.md) in `/files`

## Configure Windows DNS Server

The Windows DNS Server to be managed by Ansible should meet below requirements:
- PowerShell 3.0 or newer
- .NET 4.0 to be installed
- A WinRM listener should be created and activated

To configure WinRM, you can simply run [ConfigureRemotingForAnsible.ps1](https://raw.githubusercontent.com/jullienl/HPE-Synergy-baremetal/master/files/ConfigureRemotingForAnsible.ps1) on the Windows Server to set up the basics. 

The purpose of this script is solely for training and development, and it is strongly advised against using it in a production environment since it enables both HTTP and HTTPS listeners with a self-signed certificate and enables Basic authentication that can be inherently insecure.

To learn more about **Setting up Windows host**, see https://docs.ansible.com/ansible/2.5/user_guide/windows_setup.html#winrm-setup

## Preparation

1. Update all variables located in `/vars` and in `/group_vars/Windows.yml` for the Windows host provisioning

2. Copy the desired OS ISO versions on a web server defined by `{{ src_iso_url }}` and `{{ src_iso_file }}` variables.

3. Create an HPE Oneview Server Profile Template for each OS type.

   The following playbooks can be used to create the appropriate server profile templates:

   - `ESXi_SPT_creation_Boot_from_Logical_Drive.yml`
   - `ESXi_SPT_creation_Boot_from_SAN.yml`
   - `RHEL_SPT_creation_Boot_from_Logical_Drive.yml`
   - `RHEL_SPT_creation_Boot_from_SAN.yml`
   - `WIN_SPT_creation_Boot_from_Logical_Drive.yml`
   - `WIN_SPT_creation_Boot_from_SAN.yml`

     > **Note**: For the boot from SAN playbooks, it is necessary to activate the native mode of Jinji2 to define the size of the SAN volume, for more information, see the notes in the boot from SAN playbooks.

   Server profile templates must meet the following parameters to be compatible with bare metal provsioning playbooks:

   - UEFI secure boot is not supported, but can be enabled at a later date once the operating system has been installed.

   - Server profile templates must be defined with at least 6 network connections:

     - 2 for management
     - 2 for FCoE
     - 2 for production using a network set

       > **Note**: ESXi playbook adds a second management NIC for vswitch0 and looks for the two NICs connected to the defined network set to create the Distibuted switch for VM traffic. RHEL and Windows playbooks only create a team using the first two management NICs.

   - Server profile templates can be defined with either a boot from local storage (e.g. RAID 1 logical drive using the two internal drives) or a boot from SAN volume for operating system storage.

     > **Notes**: Additional shared/private SAN volumes for vmfs datastore/cluster volumes can also be defined (RHEL and ESXi playbooks look for the boot LUN to install the OS).

     > **IMPORTANT NOTE**: For successful boot LUN detection with RHEL and ESXi, it is essential to ensure that there are no other LUNs of the same size as the boot LUN presented to the host. Otherwise, LUN detection may fail and operating system files may be mistakenly copied to an incorrect LUN, resulting in OS boot failure.

   - Server profile templates can be defined with a firmware baseline using the `Firmware only` installation method to make sure the firmware are up-to-date before the operating system is installed but it is not a requirement. For RHEL and Windows provisioning, {{ SSP_version }} defined in the OS variable file available in the /vars folder is used to specify the server profile firmware baseline at the end of the playbooks to update HPE drivers and firmware using the HPE Smart Update Tool once the operating system is installed.

     > **Note**: For ESXi, there is no need to install HPE drivers because HPE ESXi images include all the drivers and management software required to run ESXi on HPE servers, therefore there is no need to define a firmware baseline.

## How to protect sensitive credentials

Vault files can be used to secure all passwords. To learn more, see https://docs.ansible.com/ansible/latest/user_guide/vault.html

- To encrypt a var file: `ansible-vault create --vault-id @prompt vars/encrypted_credentials.yml`
- To run a playbook with encrypted credentials: `ansible-playbook <playbook.yml> --ask-vault-pass`


## Description of the playbooks

### RHEL_provisioning.yml

This playbook performs for each inventory host the automated installation of RHEL 8.3 Boot from SAN using a customized kickstart, the main steps are as follows:

- Create a DNS record for the bare metal server in the defined Windows DNS server
- Download the OS vendor ISO file from a web server
- Mount the ISO and copy all files from the RHEL ISO image to a staging directory
- Modify Legacy bios and UEFI bootloaders for kickstart installation from CDROM
- Create a HPE OneView Server Profile from an existing Server Profile Template
  - Display Server hardware automaticaly selected by HPE OneView
- Capture the size of the primary boot volume (if any) for the customization of the kickstart file
- Customize the kickstart file with among others:
  - Set IP parameters
  - Set root password
  - Create a %pre script to detect the primary boot from SAN volume (if any)
  - Create a %post to set RHEL repositories and hostname
  - Add Ansible control node SSH public key to .ssh/authorized_keys
  - Set keyboard and language settings
  - Set time zone
  - Set ntp servers
- Generate a temporary ISO file with the customized kickstart file
- Power on and boot the inventory host from created ISO using iLO virtual media
- Wait until RHEL installation is complete
- Remove the custom ISO from the nginx web server folder and all temporary files from the staging location once the custom installation is complete.
- Install the HPE drivers for RHEL
  - Install HPE iSUT and HPE AMS on the newly provisioned server
  - Configure HPE iSUT for online installation of HPE drivers for RHEL using HPE OneView
  - Update the HPE OneView Server Profile to initiate operating system driver (and firmware if necessary) updates using HPE SUT
  - Wait until the SUT installation is complete
- Reboot the server for the activation of HPE drivers/firmware

### RHEL_unprovisioning.yml

This playbook performs for each inventory host the automated un-provisioning of the RHEL OS:

- Power off the server
- Delete the HPE OneView Server Profile
- Remove the DNS record
- Remove the host SSH key from .ssh/known_hosts

### ESXi_provisioning.yml

This playbook performs for each inventory host the automated installation of VMware ESXi 7.0.2 Boot from SAN using a customized kickstart, the main steps are as follows:

- Create a DNS record for the bare metal server in the defined Windows DNS server
- Download the HPE ESXi Custom Image ISO file from a web server
- Mount the ISO and copy all files from the ESXi HPE Custom ISO image to a staging directory
- Modify Legacy bios and UEFI bootloaders for kickstart installation from CDROM
- Create an HPE OneView Server Profile from an existing Server Profile Template
  - Display Server hardware automaticaly selected by HPE OneView
- Capture the size of the primary boot volume (if any) for the customization of the kickstart file
- Capture MAC addresses of the production NICs attached to the defined network set for subsequent configuration of the Distributed vSwitch.
- Customize the kickstart file with among others:
  - Set IP parameters
  - Set root password
  - Create a %pre script to detect the primary boot from SAN volume (if any)
  - Create a %firstboot to set hostname, DNS suffix and FQDN
  - Add Ansible control node SSH public key to /etc/ssh/keys-root/authorized_keys at %firstboot
- Generate a temporary ISO file with the customized kickstart file
- Power on and boot the inventory host from created ISO using iLO virtual media
- Wait until ESXi installation is complete
- Remove the custom ISO from the nginx web server folder and all temporary files from the staging location once the custom installation is complete.
- Create a vCenter cluster if not present and enable HA and DRS
- Add the ESXi host to the defined vCenter server
- Assign defined vSphere ESXi license to the host
- Add vmnic1 to the standard switch vSwitch0 as the second active adapter
- Add vMotion Portgroup to the standard switch vSwitch0
- Connect the host to the defined Distributed vSwitch using the available vmnics
- Set the Power Management Policy to high-performance
- Enable SSH and Shell services

### ESXi_unprovisioning.yml

This playbook performs for each inventory host the automated unprovisioning of the VMware ESXi OS:

- Put the host in maintenance mode
- Remove the Host from the defined Distributed vSwitch
- Remove the host from the defined vCenter Server
- Power off the server
- Delete HPE OneView Server Profile
- Delete DNS record

### WIN_provisioning.yml

This playbook performs for each inventory host the automated installation of Windows Server 2022 Boot from SAN using an unattended custom file, the main steps are as follows:

- Download the OS vendor ISO file from a web server
- Mount the ISO and copy all files from the Windows Server ISO image to a staging directory
- Create an HPE OneView Server Profile from an existing Server Profile Template
  - Display Server hardware automaticaly selected by HPE OneView
- Capture MAC address of first two management NICs for the configuration of the network settings in configure_network.ps1
- Create $OEM$ resources to host the scripts that need to be executed at startup:
  - Import a PowerShell script from the Ansible repository to %OEM% to configure Windows for remote management with Ansible
  - Create a PowerShell script configure_network.ps1 to be launched by SetupComplete.cmd at startup to:
    - Configure the NIC teaming with the first two NICs
    - Configure the IP parameters
- Customize the unattend file with among others:
  - Generate a standard Windows disk configuration for UEFI with four GPT partitions (WinRE/EFI/MSR/Windows):
    - WinRE: 450MB
    - EFI: 100MB
    - MSR: 16MB
    - Windows: use all available space
  - Set region and language settings
  - Set product key
  - Set registered user and organization
  - Set time zone
  - Set administrator password
  - Launch winRM installation for Ansible at startup
  - Set remote desktop
  - Set computer name
- Generate a temporary ISO file with customized unattend file and scripts
- Power on and boot the inventory host from created ISO using iLO virtual media
- Wait until Windows Server installation is complete
- Remove the custom ISO from the nginx web server folder and all temporary files from the staging location once the custom installation is complete.
- Add a DNS record for the newly provisioned server in the defined DNS server
- Install the HPE drivers for Windows Server
  - Install HPE iSUT and HPE AMS on the newly provisioned server
  - Configure HPE iSUT for online installation of HPE drivers for Windows Server using HPE OneView
  - Update the HPE OneView Server Profile to initiate operating system driver (and firmware if necessary) updates using HPE SUT
  - Wait until the SUT installation is complete
- Join the newly provisioned server to the defined Windows domain
- Reboot the server for activation of HPE drivers/firmware and domain membership

### WIN_unprovisioning.yml

This playbook performs for each inventory host the automated unprovisioning of the Windows Server OS:

- Power down the server
- Delete the HPE OneView server profile
- Delete the DNS record



## Output sample of RHEL bare metal provisioning playbook

```
ansible-playbook -i hosts RHEL9.0_provisioning.yml --ask-become-pass
BECOME password: ***********

PLAY [Creating a DNS record for the bare metal RHEL server] *******************************************************************************************************************************

TASK [Adding "RHEL90-1" with "192.168.3.177" on "dc.lj.lab" in "lj.lab" DNS domain] *******************************************************************************************************
changed: [RHEL90-1 -> dc.lj.lab]

PLAY [Performing an automated RHEL 8.3 Boot from SAN installation on a Synergy Module using a kickstart and a OneView Server Profile Template] ********************************************

TASK [Checking if RHEL ISO file "rhel-baseos-9.0-x86_64-dvd.iso" exists in "/home/labrat/ISOs/rhelisosrc" on "ansible.lj.lab"] ************************************************************
ok: [RHEL90-1 -> localhost]

TASK [Creating the directory "/home/labrat/ISOs/rhelisosrc" to host the ISO file on "ansible.lj.lab"] *************************************************************************************
skipping: [RHEL90-1]

TASK [Downloading file "rhel-baseos-9.0-x86_64-dvd.iso" to "ansible.lj.lab" in "/home/labrat/ISOs/rhelisosrc" if not present] *************************************************************
skipping: [RHEL90-1]

TASK [Collecting ISO label (can be required for some booltloader modifications)] **********************************************************************************************************
changed: [RHEL90-1 -> localhost]

TASK [set_fact] ***************************************************************************************************************************************************************************
ok: [RHEL90-1]

TASK [debug] ******************************************************************************************************************************************************************************
ok: [RHEL90-1] => {
    "msg": "RHEL-9-0-0-BaseOS-x86_64"
}

TASK [Checking if RHEL ISO file extraction is necessary in "/home/labrat/staging/baremetal/RHEL90-1" on "ansible.lj.lab"] *****************************************************************
ok: [RHEL90-1 -> localhost]

TASK [Creating "/mnt/RHEL90-1" on "ansible.lj.lab"] ***************************************************************************************************************************************
changed: [RHEL90-1 -> localhost]

TASK [Creating "/home/labrat/staging/baremetal/RHEL90-1/" on "ansible.lj.lab" if it does not exist] ***************************************************************************************
changed: [RHEL90-1 -> localhost]

TASK [Mounting RHEL ISO "/home/labrat/ISOs/rhelisosrc/rhel-baseos-9.0-x86_64-dvd.iso" to "/mnt/RHEL90-1/" and copying ISO files to "/home/labrat/staging/baremetal/RHEL90-1/" on "ansible.lj.lab"] ***
changed: [RHEL90-1 -> localhost]

TASK [Modifying legacy bios SYSLINUX bootloader for kickstart installation from CDROM] ****************************************************************************************************
changed: [RHEL90-1 -> localhost]

TASK [Modifying UEFI bootloader for kickstart installation from CDROM] ********************************************************************************************************************
changed: [RHEL90-1 -> localhost]

TASK [Creating Server Profile "RHEL90-1" from Server Profile Template "RHEL_BFS_EG_100G"] *************************************************************************************************
changed: [RHEL90-1 -> localhost]

TASK [Capturing the boot information of the first fiber channel interface of the server profile] ******************************************************************************************
ok: [RHEL90-1]

TASK [Capturing the server hardware name selected for Server Profile creation] ************************************************************************************************************
ok: [RHEL90-1]

TASK [Capturing LUN uri of the primary boot volume (if any) for the customization of the kickstart file] **********************************************************************************
ok: [RHEL90-1]

TASK [Showing the result of the Server Profile creation task] *****************************************************************************************************************************
ok: [RHEL90-1] => {
    "msg": "Hardware selected: Frame3, bay 2 - Result: Server Profile created."
}

TASK [Capturing boot volume information (if any)] *****************************************************************************************************************************************
ok: [RHEL90-1 -> localhost]

TASK [Capturing boot LUN size defined in the Server Profile to ensure that OS will be installed on this disk using the kickstart file] ****************************************************
ok: [RHEL90-1]

TASK [Setting boot LUN size as 'undefined' if booting from local logical drive] ***********************************************************************************************************
skipping: [RHEL90-1]

TASK [Creating kickstart file with %pre script to detect the "50GB" Boot From SAN volume if it exists] ************************************************************************************
changed: [RHEL90-1 -> localhost]

TASK [Creating customized bootable ISO in "/home/labrat/staging/baremetal/RHEL90-1/"] *****************************************************************************************************
changed: [RHEL90-1 -> localhost]

TASK [Implanting MD5 checksum into the ISO to make it bootable] ***************************************************************************************************************************
changed: [RHEL90-1 -> localhost]

TASK [Creating "/usr/share/nginx/html/isos/" on "ansible.lj.lab" if it does not exist] ****************************************************************************************************
ok: [RHEL90-1 -> localhost]

TASK [Moving created ISO to the nginx default html folder "http://ansible.lj.lab/isos"] ***************************************************************************************************
changed: [RHEL90-1 -> localhost]

TASK [Update SELinux security contexts so that Nginx is allowed to serve content from the "/usr/share/nginx/html/isos/" directory.] *******************************************************
changed: [RHEL90-1 -> localhost]

TASK [Powering on and booting "Frame3, bay 2" from created ISO using iLO Virtual Media] ***************************************************************************************************
changed: [RHEL90-1 -> localhost]

TASK [Waiting for RHEL installation to complete - Waiting for "192.168.3.177" to respond...] **********************************************************************************************
ok: [RHEL90-1 -> localhost]

TASK [debug] ******************************************************************************************************************************************************************************
ok: [RHEL90-1] => {
    "msg": "RHEL90-1 installation took 10 minutes"
}

TASK [Deleting all temporary files in the stagging location on "ansible.lj.lab"] **********************************************************************************************************
changed: [RHEL90-1 -> localhost]

TASK [Deleting created ISO file in the web server directory at "http://ansible.lj.lab/isos/"] *********************************************************************************************
changed: [RHEL90-1 -> localhost]

TASK [Unmounting original ISO file on "ansible.lj.lab"] ***********************************************************************************************************************************
changed: [RHEL90-1 -> localhost]

TASK [Copying HPE iSUT rpm file to RHEL90-1] **********************************************************************************************************************************************
changed: [RHEL90-1]

TASK [Copying HPE AMS rpm file to RHEL90-1] ***********************************************************************************************************************************************
changed: [RHEL90-1]

TASK [Installing iSUT] ********************************************************************************************************************************************************************
changed: [RHEL90-1]

TASK [Installing AMS] *********************************************************************************************************************************************************************
changed: [RHEL90-1]

TASK [Waiting for iSUT installation to complete] ******************************************************************************************************************************************
ok: [RHEL90-1 -> localhost]

TASK [Configuring iSUT mode to allow OS driver updates via HPE OneView Server Profile] ****************************************************************************************************
changed: [RHEL90-1]

TASK [debug] ******************************************************************************************************************************************************************************
ok: [RHEL90-1] => {
    "msg": "SUT Service started successfully\nRegistration successful\nCommunication to iLO failed. If iLO is configured in any of the higher security modes, then use sut -set ilousername=<username> ilopassword=<password> to set the iLO credentials. If iLO is in CAC mode, then use sut -addcertificate <path_to_certificate_file> to set the certificate details\nThe configuration changes for the command will be saved once the details are provided\nSet Mode: autodeploy\nService will be registered and started\nService already registered\nSUT Service is already running\nRegistration successful"
}

TASK [Configuring iSUT credentials to communicate with iLO] *******************************************************************************************************************************
changed: [RHEL90-1]

TASK [Capturing facts about the HPE Synergy Service Pack "SY-2023.05.01"] *****************************************************************************************************************
ok: [RHEL90-1 -> localhost]

TASK [Capturing HPE Synergy Service Pack "SY-2023.05.01" firmware baseline uri] ***********************************************************************************************************
ok: [RHEL90-1]

TASK [Setting HPE Synergy Service Pack "SY-2023.05.01" as the firmware baseline of server profile "RHEL90-1" and enabling Firmware and OS Drivers using SUT] ******************************
changed: [RHEL90-1 -> localhost]

TASK [debug] ******************************************************************************************************************************************************************************
ok: [RHEL90-1] => {
    "msg": "Server profile updated"
}

TASK [Monitoring SUT status for 'reboot the system' message] ******************************************************************************************************************************
FAILED - RETRYING: [RHEL90-1 -> localhost]: Monitoring SUT status for 'reboot the system' message (100 retries left).
FAILED - RETRYING: [RHEL90-1 -> localhost]: Monitoring SUT status for 'reboot the system' message (99 retries left).
FAILED - RETRYING: [RHEL90-1 -> localhost]: Monitoring SUT status for 'reboot the system' message (98 retries left).
FAILED - RETRYING: [RHEL90-1 -> localhost]: Monitoring SUT status for 'reboot the system' message (97 retries left).
FAILED - RETRYING: [RHEL90-1 -> localhost]: Monitoring SUT status for 'reboot the system' message (96 retries left).
FAILED - RETRYING: [RHEL90-1 -> localhost]: Monitoring SUT status for 'reboot the system' message (95 retries left).
FAILED - RETRYING: [RHEL90-1 -> localhost]: Monitoring SUT status for 'reboot the system' message (94 retries left).
FAILED - RETRYING: [RHEL90-1 -> localhost]: Monitoring SUT status for 'reboot the system' message (93 retries left).
FAILED - RETRYING: [RHEL90-1 -> localhost]: Monitoring SUT status for 'reboot the system' message (92 retries left).
FAILED - RETRYING: [RHEL90-1 -> localhost]: Monitoring SUT status for 'reboot the system' message (91 retries left).
FAILED - RETRYING: [RHEL90-1 -> localhost]: Monitoring SUT status for 'reboot the system' message (90 retries left).
FAILED - RETRYING: [RHEL90-1 -> localhost]: Monitoring SUT status for 'reboot the system' message (89 retries left).
FAILED - RETRYING: [RHEL90-1 -> localhost]: Monitoring SUT status for 'reboot the system' message (88 retries left).
ok: [RHEL90-1 -> localhost]

TASK [Displaying install completed message] ***********************************************************************************************************************************************
ok: [RHEL90-1] => {
    "msg": [
        "RHEL90-1.lj.lab Installation completed !",
        "OS is configured and running the HPE OS drivers and firmware update.",
        "Check Server Profile activity of RHEL90-1 in HPE OneView.",
        "To connect to the new host from Ansible control node, use: ssh root@192.168.3.177"
    ]
}

PLAY RECAP ********************************************************************************************************************************************************************************
RHEL90-1                   : ok=44   changed=27   unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   



```

## Output sample of RHEL bare metal unprovisioning playbook

```
ansible-playbook -i "rhel90-1," Unprovisioning_server.yml 

PLAY [Deleting provisioned compute module(s)] *************************************************************************************************************************

TASK [Checking if server profile "rhel90-1" exists] *******************************************************************************************************************
ok: [rhel90-1 -> localhost]

TASK [Getting server profile "rhel90-1" information] *****************************************************************************************************************
changed: [rhel90-1 -> localhost]

TASK [Powering off server hardware "rhel90-1"] ***********************************************************************************************************************
ok: [rhel90-1 -> localhost]

TASK [Deleting server profile "rhel90-1"] ****************************************************************************************************************************
changed: [rhel90-1 -> localhost]

TASK [Result of the task to delete the server profile] ***************************************************************************************************************
ok: [rhel90-1] => {
    "msg": "Deleted profile"
}

TASK [Removing rhel90-1 SSH key] *************************************************************************************************************************************
changed: [rhel90-1 -> localhost]

PLAY [Removing the DNS record from DNS server] ***********************************************************************************************************************

TASK [Removing "rhel90-1" from "dc.lj.lab"] **************************************************************************************************************************
changed: [rhel90-1 -> dc.lj.lab]

PLAY RECAP ***********************************************************************************************************************************************************
rhel90-1                   : ok=7    changed=4    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   

```

## Output sample of ESXi bare metal provisioning playbook

```
ansible-playbook -i hosts ESXi_provisioning.yml --ask-become-pass
BECOME password: ***********

PLAY [Creating a DNS record for the bare metal ESXi server] *************************************************************************************************************************

TASK [Adding "ESX-1" with "192.168.3.171" on "dc.lj.lab" in "lj.lab" DNS domain] ****************************************************************************************************
changed: [ESX-1 -> dc.lj.lab]

PLAY [Performing an automated ESXi 7.0 U2 Boot from SAN installation on a Synergy Module using a kickstart and a OneView Server Profile Template] ***********************************

TASK [Checking if HPE ESXi Custom ISO file "VMware-ESXi-7.0.3-21930508-HPE-703.0.0.11.3.5.9-Aug2023-Synergy.iso" exists in "/home/labrat/ISOs/esxiisosrc" on "ansible.lj.lab"] ******
ok: [ESX-1 -> localhost]

TASK [Creating the directory "/home/labrat/ISOs/esxiisosrc" to host the ISO file on "ansible.lj.lab"] *******************************************************************************
skipping: [ESX-1]

TASK [Downloading file "VMware-ESXi-7.0.3-21930508-HPE-703.0.0.11.3.5.9-Aug2023-Synergy.iso" to "ansible.lj.lab" in "/home/labrat/ISOs/esxiisosrc" if not present] ******************
skipping: [ESX-1]

TASK [Checking if HPE ESXi Custom ISO file extraction is necessary in "/home/labrat/staging/baremetal/ESX-1" on "ansible.lj.lab"] ***************************************************
ok: [ESX-1 -> localhost]

TASK [Creating "/mnt/ESX-1" on "ansible.lj.lab" if it does not exist] ***************************************************************************************************************
changed: [ESX-1 -> localhost]

TASK [Creating "/home/labrat/staging/baremetal/ESX-1/" on "ansible.lj.lab" if it does not exist] ************************************************************************************
changed: [ESX-1 -> localhost]

TASK [Creating "/home/labrat/staging/baremetal/temp/ESX-1/" on "ansible.lj.lab" if it does not exist] *******************************************************************************
changed: [ESX-1 -> localhost]

TASK [Creating "/home/labrat/staging/baremetal/temp/ESX-1/etc/vmware/weasel" on "ansible.lj.lab" if it does not exist] **************************************************************
changed: [ESX-1 -> localhost]

TASK [Mounting HPE ESXi Custom ISO "/home/labrat/ISOs/esxiisosrc/VMware-ESXi-7.0.3-21930508-HPE-703.0.0.11.3.5.9-Aug2023-Synergy.iso" to "/mnt/ESX-1/" and copying ISO files to "/home/labrat/staging/baremetal/ESX-1/" on "ansible.lj.lab"] *********
changed: [ESX-1 -> localhost]

TASK [Modifying legacy bios SYSLINUX bootloader for kickstart installation from CDROM] **********************************************************************************************
changed: [ESX-1 -> localhost]

TASK [Modifying UEFI bootloader for kickstart installation from CDROM] **************************************************************************************************************
changed: [ESX-1 -> localhost]

TASK [Creating Server Profile "ESX-1" from Server Profile Template "ESXi_BFS_EG_100G"] **********************************************************************************************
changed: [ESX-1 -> localhost]

TASK [Capturing the boot information of the first fiber channel interface of the server profile] ************************************************************************************
ok: [ESX-1]

TASK [Capturing network set information from "Production_network_set" attached to the two production NICs] **************************************************************************
ok: [ESX-1 -> localhost]

TASK [Capturing the URI of network "Production_network_set" attached to the two production NICs] ************************************************************************************
ok: [ESX-1]

TASK [Capturing the server hardware name selected for Server Profile creation] ******************************************************************************************************
ok: [ESX-1]

TASK [Capturing MAC addresses of the production NICs attached to "Production_network_set" for subsequent configuration of the Distributed vSwitch.] *********************************
ok: [ESX-1]

TASK [Capturing LUN uri of the primary boot volume (if any) for the customization of the kickstart file] ****************************************************************************
ok: [ESX-1]

TASK [Showing the result of the Server Profile creation task] ***********************************************************************************************************************
ok: [ESX-1] => {
    "msg": "Hardware selected: Frame3, bay 3 - Result: Server Profile created."
}

TASK [Capturing boot volume information (if any)] ***********************************************************************************************************************************
ok: [ESX-1 -> localhost]

TASK [Capturing boot LUN size defined in the Server Profile to ensure that OS will be installed on this disk using the kickstart file] **********************************************
ok: [ESX-1]

TASK [Setting boot LUN size as 'undefined' if booting from local logical drive] *****************************************************************************************************
skipping: [ESX-1]

TASK [Creating kickstart file with %pre script to detect the "20GB" Boot From SAN volume if it exists] ******************************************************************************
changed: [ESX-1 -> localhost]

TASK [Preparing ks.cfg kickstart file to make the new ISO in "/home/labrat/staging/baremetal/temp/ESX-1/etc/vmware/weasel/ks.cfg"] **************************************************
changed: [ESX-1 -> localhost]

TASK [Creating the ks.tgz kickstart file to make the new ISO] ***********************************************************************************************************************
changed: [ESX-1 -> localhost]

TASK [Copying new ks.tgz to "/home/labrat/staging/baremetal/ESX-1/"] ****************************************************************************************************************
changed: [ESX-1 -> localhost]

TASK [Creating customized bootable ISO in "/home/labrat/staging/baremetal/ESX-1/"] **************************************************************************************************
changed: [ESX-1 -> localhost]

TASK [Creating "/usr/share/nginx/html/isos/" on "ansible.lj.lab" if it does not exist] **********************************************************************************************
ok: [ESX-1 -> localhost]

TASK [Moving created ISO to the nginx default html folder "http://ansible.lj.lab/isos"] *********************************************************************************************
changed: [ESX-1 -> localhost]

TASK [Update SELinux security contexts so that Nginx is allowed to serve content from the "/usr/share/nginx/html/isos/" directory.] *************************************************
changed: [ESX-1 -> localhost]

TASK [Powering on and booting "Frame3, bay 3" from created ISO using iLO Virtual Media] *********************************************************************************************
changed: [ESX-1 -> localhost]

TASK [Waiting for ESXi installation to complete - waiting for "192.168.3.171" to respond...] ****************************************************************************************
ok: [ESX-1 -> localhost]

TASK [debug] ************************************************************************************************************************************************************************
ok: [ESX-1] => {
    "msg": "ESX-1 installation took 14 minutes"
}

TASK [Wait a little longer so that the ESX host is truly ready to be added to vCenter] **********************************************************************************************
ok: [ESX-1 -> localhost]

TASK [Deleting all related files from staging location and nginx web server folder] *************************************************************************************************
changed: [ESX-1 -> localhost]

TASK [Creating ESXi cluster "Synergy-Cluster-01" in vCenter "vcenter.lj.lab" if not present] ****************************************************************************************
changed: [ESX-1 -> localhost]

TASK [Enabling HA without admission control on "Synergy-Cluster-01" cluster] ********************************************************************************************************
changed: [ESX-1 -> localhost]

TASK [Enabling DRS with VM distribution across hosts for availability on "Synergy-Cluster-01" cluster] ******************************************************************************
changed: [ESX-1 -> localhost]

TASK [Adding ESXi host "esx-1.lj.lab" to "Synergy-Cluster-01" cluster] **************************************************************************************************************
changed: [ESX-1 -> localhost]

TASK [Assigning ESXi license to Host] ***********************************************************************************************************************************************
changed: [ESX-1 -> localhost]

TASK [Adding vmnic1 to standard switch vSwitch0] ************************************************************************************************************************************
changed: [ESX-1 -> localhost]

TASK [Pause for 10 seconds to give time for the vswitch0 configuration] *************************************************************************************************************
Pausing for 10 seconds
(ctrl+C then 'C' = continue early, ctrl+C then 'A' = abort)
ok: [ESX-1]

TASK [Adding vMotion Portgroup to standard switch vSwitch0] *************************************************************************************************************************
changed: [ESX-1 -> localhost]

TASK [Pause for 10 seconds to give time for the vswitch0 configuration] *************************************************************************************************************
Pausing for 10 seconds
(ctrl+C then 'C' = continue early, ctrl+C then 'A' = abort)
ok: [ESX-1]

TASK [Gathering facts about vmnics] *************************************************************************************************************************************************
ok: [ESX-1 -> localhost]

TASK [Capturing Production vmnics information for the distributed switch creation] **************************************************************************************************
ok: [ESX-1]

TASK [Connecting host to "DSwitch-VC100G" distributed switch] ***********************************************************************************************************************
changed: [ESX-1 -> localhost]

TASK [Adding vmkernel mk1 port to "DSwitch-VC100G" distributed Switch] **************************************************************************************************************
changed: [ESX-1 -> localhost]

TASK [Changing Advanced Settings with Core Dump Warning Disable] ********************************************************************************************************************
changed: [ESX-1 -> localhost]

TASK [Setting the Power Management Policy to high-performance] **********************************************************************************************************************
changed: [ESX-1 -> localhost]

TASK [Configuring NTP servers] ******************************************************************************************************************************************************
changed: [ESX-1 -> localhost]

TASK [Starting NTP Service and set to start at boot.] *******************************************************************************************************************************
changed: [ESX-1 -> localhost]

TASK [Starting ESXi Shell Service and setting to enable at boot . . .] **************************************************************************************************************
changed: [ESX-1 -> localhost]

TASK [Starting SSH Service and setting to enable at boot.] **************************************************************************************************************************
changed: [ESX-1 -> localhost]

TASK [Displaying install completed message] *****************************************************************************************************************************************
ok: [ESX-1] => {
    "msg": [
        "ESX-1.lj.lab Installation completed !",
        "ESXi is configured and running. It has been added to the vCenter cluster 'Synergy-Cluster-01'."
    ]
}

PLAY RECAP ***************************************************************************************************************************************************************************
ESX-1                      : ok=53   changed=33   unreachable=0    failed=0    skipped=3    rescued=0    ignored=0   

```

## Output sample of ESXi bare metal unprovisioning playbook

```
ansible-playbook -i "ESX-1," ESXi_unprovisioning.yml 

PLAY [Deleting a provisioned ESXi compute module] *****************************************************************

TASK [Taking "esx-1.lj.lab" to maintenance mode] ******************************************************************
changed: [ESX-1 -> localhost]

TASK [Removing vmkernel mk1 port from "DSwitch-VC100G" distributed Switch] ****************************************
changed: [ESX-1 -> localhost]

TASK [Gathering facts about vmnics] *******************************************************************************
ok: [ESX-1 -> localhost]

TASK [Capturing available vmnics for the distributed switch creation] *********************************************
ok: [ESX-1]

TASK [Removing host from "DSwitch-VC100G" distributed Switch] *****************************************************
changed: [ESX-1 -> localhost]

TASK [Removing ESXi host "esx-1.lj.lab" from vCenter "vcenter.lj.lab"] ********************************************
changed: [ESX-1 -> localhost]

TASK [Getting server profile "ESX-1" information] *****************************************************************
ok: [ESX-1 -> localhost]

TASK [Powering off server hardware "Frame3, bay 2"] ***************************************************************
changed: [ESX-1 -> localhost]

TASK [Deleting server profile "ESX-1"] ****************************************************************************
changed: [ESX-1 -> localhost]

TASK [Result of the task to delete the server profile] ************************************************************
ok: [ESX-1] => {
    "msg": "Deleted profile"
}

PLAY [Removing the DNS record for the bare metal ESXi server] *****************************************************

TASK [Removing "192.168.3.171"" from "dc.lj.lab"] *****************************************************************
changed: [ESX-1 -> dc.lj.lab]

PLAY RECAP ********************************************************************************************************
ESX-1                      : ok=11   changed=7    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   

```

## Output sample of Windows Server bare metal provisioning playbook

```
ansible-playbook -i hosts WIN_provisioning.yml --ask-become-pass
BECOME password: **********


PLAY [Performing an unattended Windows Server 2022 Boot from SAN installation on a Gen10 Synergy Module using a OneView Server Profile Template] ****************************************

TASK [Checking if Windows Server ISO file "en-us_windows_server_version_2022_updated_october_2021_x64_dvd_b6e25591.iso" exists in "/home/labrat/ISOs/rhelisosrc" on "ansible.lj.lab"] ***
ok: [WIN-1 -> localhost]

TASK [Creating the directory "/home/labrat/ISOs/rhelisosrc" to host the ISO file on "ansible.lj.lab"] *****************************************************************************************************************************************************************************************
changed: [WIN-1]

TASK [Downloading file "en-us_windows_server_version_2022_updated_october_2021_x64_dvd_b6e25591.iso" to "ansible.lj.lab" in "/home/labrat/ISOs/rhelisosrc" if not present] **************
changed: [WIN-1]

TASK [Checking if Windows Server ISO file extraction is necessary in "/home/labrat/staging/baremetal/WIN-1" on "ansible.lj.lab"] ********************************************************
ok: [WIN-1 -> localhost]

TASK [Creating /mnt/WIN-1 on "ansible.lj.lab" if it does not exist] *********************************************************************************************************************
changed: [WIN-1 -> localhost]

TASK [Creating "/home/labrat/staging/baremetal/WIN-1/" on "ansible.lj.lab" if it does not exist] ****************************************************************************************
changed: [WIN-1 -> localhost]

TASK [Mounting Windows Server ISO  "/home/labrat/ISOs/rhelisosrc/en-us_windows_server_version_2022_updated_october_2021_x64_dvd_b6e25591.iso" to "/mnt/WIN-1/"  and copying ISO files to "/home/labrat/staging/baremetal/WIN-1/" on "ansible.lj.lab"] **********
changed: [WIN-1 -> localhost]

TASK [Creating $OEM$ on "ansible.lj.lab" in /home/labrat/staging/baremetal/WIN-1/sources to execute scripts at startup] *****************************************************************
changed: [WIN-1 -> localhost] => (item=/home/labrat/staging/baremetal/WIN-1/sources/$OEM$)
changed: [WIN-1 -> localhost] => (item=/home/labrat/staging/baremetal/WIN-1/sources/$OEM$/$1)
changed: [WIN-1 -> localhost] => (item=/home/labrat/staging/baremetal/WIN-1/sources/$OEM$/$1/Temp)
changed: [WIN-1 -> localhost] => (item=/home/labrat/staging/baremetal/WIN-1/sources/$OEM$/$$)
changed: [WIN-1 -> localhost] => (item=/home/labrat/staging/baremetal/WIN-1/sources/$OEM$/$$/Setup)
changed: [WIN-1 -> localhost] => (item=/home/labrat/staging/baremetal/WIN-1/sources/$OEM$/$$/Setup/Scripts)

TASK [Download POSH script from GitHub to configure Windows for remote management with Ansible] *****************************************************************************************
changed: [WIN-1 -> localhost]

TASK [Creating Server Profile "WIN-1" from Server Profile Template "WIN_BFS_EG_100G"] ***************************************************************************************************
changed: [WIN-1 -> localhost]

TASK [Capturing the server hardware name selected for Server Profile creation] **********************************************************************************************************
ok: [WIN-1]

TASK [Capturing MAC of first two management NICs for the configuration of the network settings in configure_network.ps1] ****************************************************************
ok: [WIN-1]

TASK [Showing the result of the Server Profile creation task] ***************************************************************************************************************************
ok: [WIN-1] => {
    "msg": "Hardware selected: Frame4, bay 4 - Result: Server Profile created."
}

TASK [Creating configure_network.ps1 that will be launched by SetupComplete.cmd (creation of a team using the first two NICs and configuration of IP parameters)] ***********************
changed: [WIN-1 -> localhost]

TASK [Creating SetupComplete.cmd for the network settings] *****************************************************************************************************************************************************************************************
changed: [WIN-1 -> localhost]

TASK [Updating autounattend.xml file] *****************************************************************************************************************************************************************************************
changed: [WIN-1 -> localhost]

TASK [Creating customized bootable ISO in "/home/labrat/staging/baremetal/WIN-1/"] ******************************************************************************************************
changed: [WIN-1 -> localhost]

TASK [Creating /usr/share/nginx/html/isos/ on "ansible.lj.lab" if it does not exist] ****************************************************************************************************
ok: [WIN-1 -> localhost]

TASK [Moving created ISO to the nginx default html folder of "ansible.lj.lab"] **********************************************************************************************************

TASK [Update SELinux security contexts so that Nginx is allowed to serve content from the "/usr/share/nginx/html/isos/" directory.] *****************************************************
changed: [WIN-1 -> localhost]

TASK [Powering on and booting "Frame4, bay 4" from created ISO using iLO Virtual Media] *************************************************************************************************
changed: [WIN-1 -> localhost]

TASK [Waiting for Windows Server installation to complete - Waiting for "192.168.3.175" to respond...] **********************************************************************************
ok: [WIN-1 -> localhost]

TASK [debug] ****************************************************************************************************************************************************************************
ok: [WIN-1] => {
    "msg": "WIN-1 installation took 22 minutes"
}

TASK [Deleting all temporary files in the stagging location on "ansible.lj.lab"] ********************************************************************************************************
changed: [WIN-1 -> localhost]

TASK [Deleting created ISO file in the web server directory on "ansible.lj.lab"] ********************************************************************************************************
changed: [WIN-1 -> localhost]

TASK [Unmounting original ISO file on "ansible.lj.lab"] *********************************************************************************************************************************
changed: [WIN-1 -> localhost]

TASK [Collecting product_id found in install.xml file of the HPE iSUT package] **********************************************************************************************************
changed: [WIN-1 -> localhost]

TASK [Collecting product_id found in install.xml file of the HPE AMS package] ***********************************************************************************************************
changed: [WIN-1 -> localhost]

PLAY [Creating a DNS record for the bare metal Windows Server] **************************************************************************************************************************

TASK [Adding "WIN-1" with "192.168.3.175" on "dc.lj.lab" in "lj.lab" DNS domain] ********************************************************************************************************
changed: [WIN-1 -> dc.lj.lab]

PLAY [Installing HPE iSUT and HPE AMS on the server for online installation of HPE drivers for Windows Server] **************************************************************************

TASK [Copying HPE iSUT package file to WIN-1] *******************************************************************************************************************************************
changed: [WIN-1]

TASK [Copying HPE AMS package file to WIN-1] ********************************************************************************************************************************************
changed: [WIN-1]

TASK [Installing Integrated Smart Update Tools] *****************************************************************************************************************************************
ok: [WIN-1]

TASK [Installing HPE Agentless Management Service] **************************************************************************************************************************************
ok: [WIN-1]

TASK [Configuring iSUT mode to allow OS driver updates via HPE OneView Server Profile] **************************************************************************************************
changed: [WIN-1]

TASK [debug] ****************************************************************************************************************************************************************************
ok: [WIN-1] => {
    "msg": "SUT Service started successfully\r\nRegistration successful\r\nCommunication to iLO failed. If iLO is configured in any of the higher security modes, then use sut -set ilousername=<username> ilopassword=<password> to set the iLO credentials. If iLO is in CAC mode, then use sut -addcertificate <path_to_certificate_file> to set the certificate details\r\nThe configuration changes for the command will be saved once the details are provided\r\nSet Mode: autodeploy\r\nService will be registered and started\r\nService already registered\r\nSUT Service is already running\r\nRegistration successful\r\n"
}

TASK [Configuring iSUT credentials to communicate with iLO] *******************************************************************************************************************************
changed: [WIN-1]

TASK [Capturing facts about the HPE Synergy Service Pack "SY-2023.05.01"] *****************************************************************************************************************
ok: [WIN-1 -> localhost]

TASK [Capturing HPE Synergy Service Pack "SY-2023.05.01" firmware baseline uri] ***********************************************************************************************************
ok: [WIN-1]

TASK [Setting HPE Synergy Service Pack "SY-2023.05.01" as the firmware baseline of server profile "WIN-1" and enabling Firmware and OS Drivers using SUT] *********************************
changed: [WIN-1 -> localhost]

TASK [debug] ******************************************************************************************************************************************************************************
ok: [WIN-1] => {
    "msg": "Server profile updated"
}


TASK [Joining domain lj.lab] **************************************************************************************************************************************************************
changed: [WIN-1]

TASK [Monitoring SUT status for 'reboot the system' message] ******************************************************************************************************************************
FAILED - RETRYING: [WIN-1 -> localhost]: Monitoring SUT status for 'reboot the system' message (100 retries left).
FAILED - RETRYING: [WIN-1 -> localhost]: Monitoring SUT status for 'reboot the system' message (99 retries left).
FAILED - RETRYING: [WIN-1 -> localhost]: Monitoring SUT status for 'reboot the system' message (98 retries left).
FAILED - RETRYING: [WIN-1 -> localhost]: Monitoring SUT status for 'reboot the system' message (97 retries left).
FAILED - RETRYING: [WIN-1 -> localhost]: Monitoring SUT status for 'reboot the system' message (96 retries left).
FAILED - RETRYING: [WIN-1 -> localhost]: Monitoring SUT status for 'reboot the system' message (95 retries left).
FAILED - RETRYING: [WIN-1 -> localhost]: Monitoring SUT status for 'reboot the system' message (94 retries left).
FAILED - RETRYING: [WIN-1 -> localhost]: Monitoring SUT status for 'reboot the system' message (93 retries left).
FAILED - RETRYING: [WIN-1 -> localhost]: Monitoring SUT status for 'reboot the system' message (92 retries left).
FAILED - RETRYING: [WIN-1 -> localhost]: Monitoring SUT status for 'reboot the system' message (91 retries left).
FAILED - RETRYING: [WIN-1 -> localhost]: Monitoring SUT status for 'reboot the system' message (90 retries left).
ok: [WIN-1 -> localhost]

TASK [Displaying install completed message] *******************************************************************************************************************************************************************************************
ok: [WIN-1] => {
    "msg": [
        "WIN-1.lj.lab Installation completed !",
        "OS is configured and running the HPE OS drivers and firmware update.",
        "Check Server Profile activity of WIN-1 in HPE OneView."
    ]
}

PLAY RECAP *******************************************************************************************************************************************************************************
WIN-1                      : ok=44   changed=27   unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   

```

## Output sample of Windows Server bare metal unprovisioning playbook

```

ansible-playbook -i "WIN-1," Unprovisioning_server.yml 

PLAY [Deleting provisioned compute module(s)] ************************************************************************************************************************

TASK [Checking if server profile "WIN-1" exists] *********************************************************************************************************************
ok: [WIN-1 -> localhost]

TASK [Getting server profile "WIN-1" information] ********************************************************************************************************************
changed: [WIN-1 -> localhost]

TASK [Powering off server hardware "WIN-1"] **************************************************************************************************************************
ok: [WIN-1 -> localhost]

TASK [Deleting server profile "WIN-1"] *******************************************************************************************************************************
changed: [WIN-1 -> localhost]

TASK [Result of the task to delete the server profile] ***************************************************************************************************************
ok: [WIN-1] => {
    "msg": "Deleted profile"
}

TASK [Removing WIN-1 SSH key] ****************************************************************************************************************************************
changed: [WIN-1 -> localhost]

PLAY [Removing the DNS record from DNS server] ***********************************************************************************************************************

TASK [Removing "WIN-1" from "dc.lj.lab"] *****************************************************************************************************************************
changed: [WIN-1 -> dc.lj.lab]

PLAY RECAP ***********************************************************************************************************************************************************
WIN-1                   : ok=7    changed=4    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
```

## Thank you

Thank you to bryansullins for his inspiring work for [baremetalesxi](https://github.com/bryansullins/baremetalesxi).

## License

This project is licensed under the MIT License - see the LICENSE file for details
