# FILENET CONTENT MANAGER ON REDHAT OPENSHIFT(IBM CLOUD)

This article is intended to guide readers into an easy installation of a simple IBM Filenet Content Manager instance using IBM Cloud managed Openshift Cluster.
This steps are for demonstrations only and not intended for an actual environment. Security and performance considerations must be addressed for each component in any installation

***
### ARCHITECTURE

IBM Cloud components used were:
1. A small Openshift cluster of two worker nodes (4x16) in vpc
2. A virtual server instance (8x16) with RHEL 8.x

Installers used:
1. ds64-premium-feature-act-pkg.zip --> activation package for IBM Security Directory Server 6.4
2. sds64-linux-x86-64.iso  --> ISO file for IBM Security Directory Server
3. DB2_AWSE_REST_Svr_11.1_Lnx_86-64.tar.gz ---> installer file for IBM DB2 11.1.x
4. DB2_AWSE_Restricted_Activation_11.1.zip ---> activation package for IBM DB2 11.1.x
***
### Preparing the Databases

1. First you must login into the virtual server instance of IBM Cloud
- You will need the private key pair of the public key used to create the virtual instance and also the assigned IP address
```
ssh -X -C -i id_rsa root@169.59.xxx.xxx
```

2. The aditional packages nedded fot IBM DB2 11.x must be installed
```
#yum install libaio.so.1 -y
#yum install pam-devel -y
#yum install libaio -y
#yum install libpam.so.0 -y
#yum install binutils -y
#yum install libstdc++.so.6 -y
#yum install libXext.so.6 -y
#yum install  xorg-x11-server-Xorg xorg-x11-xauth -y
#yum install unzip -y
#xhost +
#export DISPLAY=:10.0
```
3. Copy the DB2 installer files into the virtual server, you can use a tool such as Filezilla to do this


4. Install DB2 using the following commands:
* Untar the installers:
```
#cd {$INSTALLER_DIRECORY}
#tar -xvf DB2_AWSE_REST_Svr_11.1_Lnx_86-64.tar.gz
#unzip DB2_AWSE_Restricted_Activation_11.1.zip
```

* Install DB2 using the wizard, take special notes of the user and password used for the db2 instance
```
#cd server_awse_o
#./db2setup
```

* Apply the db2 licence for the installation
```
#cd /opt/ibm/db2/V11.1/adm
#./db2licm -a {$INSTALLER_DIRECORY}/awse_o/db2/license/db2awse_o.lic
```
5. Create the required databases
* Using the files provided in the [db2](https://github.com/fxnaranjo/filenet/tree/main/db2) folder on this repo, run the following commands:
```
#su - db2inst1
#./GCDDB.sh GCDDB   ----> CREATES the GCD Database with the provided name
#./OS1DB.sh OSDB    ----> CREATES the Object Store Database with the provided name
./createICNDB.sh -n ICNDB -s ICN_SH -t ICN_TS -u db2inst1 -a ceadmin ----> CREATES the Content Navigator Database with the provided name
```

***
### Preparing the LDAP Server
* Unzip the installers:
```
#cd {$INSTALLER_DIRECORY}
#unzip sds64-premium-feature-act-pkg.zip
```
* Mount the installer
```
#mkdir -p /mnt/iso
#mount -t iso9660 -o loop {$INSTALLER_DIRECORY}/sds64-linux-x86-64.iso /mnt/iso/
#yum install ksh -y
```

* Setup ldap user and group
```
#groupadd idsldap
#useradd -g idsldap -d /home/idsldap -m -s /bin/ksh idsldap
#passwd idsldap
#--> enter '<your-password>'
#usermod -a -G idsldap root
```

* Skip db2 installation
```
#mkdir -p /opt/ibm/ldap/V6.4/install
#touch /opt/ibm/ldap/V6.4/install/IBMLDAP_INSTALL_SKIPDB2REQ
```
* Install gskit
```
#cd /mnt/iso/ibm_gskit
#rpm -Uhv gsk*linux.x86_64.rpm
```
* Install Directory Server rpms
```
#cd /mnt/iso/license
./idsLicense
## Enter 1 to accept the license agreement
#cd /mnt/iso/images
#rpm --force -ihv idsldap*rpm
```
* Apply the license
```
#cd {$INSTALLER_DIRECORY}/sdsV6.4/entitlement
#rpm --force -ihv idsldap-ent64-6.4.0-0.x86_64.rpm
```

* Install ibm jdk
```
#cd /mnt/iso/ibm_jdk
#tar -xf 6.0.16.2-ISS-JAVA-LinuxX64-FP0002.tar -C /opt/ibm/ldap/V6.4/
```

* Setup db2 path
```
vi /opt/ibm/ldap/V6.4/etc/ldapdb.properties
currentDB2InstallPath=/opt/ibm/db2/V11.1
currentDB2Version=11.1.4.5
```

* Create and configure instance
```
cd /opt/ibm/ldap/V6.4/sbin
./idsadduser -u dsinst1 -g grinst1 -w 020kw31xx
## Enter 1 to continue
```

* Create instance
```
./idsicrt -I dsinst1 -p 389 -s 636 -e mysecretkey! -l /home/dsinst1 -G grinst1 -w <password>
## Enter 1 to continue
```

* Configure a database for a directory server instance.
```
#./idscfgdb -I dsinst1 -a dsinst1 -w <password> -t dsinst1 -l /home/dsinst1
```

* Set the administration DN and administrative password for an instance
```
#./idsdnpw -I dsinst1 –u cn=root –p <password>
```
* Add suffix
```
#./idscfgsuf -I dsinst1 -s o=IBM,c=US
```
* Start the directory server
```
#./ibmslapd -I dsinst1
```
* Verify the server
```
#cd /opt/ibm/ldap/V6.4/bin
#./ldapsearch -h ldap://localhost:389 -s base -b " " objectclass=* ibm-slapdisconfigurationmode
```
* Create sample user and gruops using ldif
1. Use the files provided in the [ldap](https://github.com/fxnaranjo/filenet/tree/main/ldap) folder on this repo.
2. You can use tools such as [Apache Directory Studio](https://directory.apache.org/studio/) to manage the ldap instance.

***
### Preparing the NFS SERVER
* Install and enable nfs service
```
#yum install nfs-utils -y
#systemctl enable nfs-server.service
```
* Configure nfs server
```
#mkdir -p /var/nfsshare
#chown nobody:nobody /var/nfsshare
#chmod 777 /var/nfsshare
#vi /etc/exports ---> /var/nfsshare *(rw,sync,no_subtree_check)
#exportfs -a
#systemctl start nfs-server.service
```


