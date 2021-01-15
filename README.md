# FILENET CONTENT MANAGER ON REDHAT OPENSHIFT(IBM CLOUD)

This article is intented to guide readers into an easy installation of a simple IBM Filenet Content Manager instance using IBM Cloud managed Openshift Cluster

***
### ARCHITECTURE

IBM Cloud components used were:
1. A small Openshift cluster of two worker nodes (4x16) in vpc
2. A virtual server instance (8x16) with RHEL 8.x

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
3. Copy the db2 and IBM Direcotry Server installer files into the virtual server, you can use a tool such as Filezilla to to this


4.-INSTALL DB2 using the following commands:
* Untar the installers:
```
#cd {$INSTALLER_DIRECORY}
#tar -xvf DB2_AWSE_REST_Svr_11.1_Lnx_86-64.tar.gz
#unzip DB2_AWSE_Restricted_Activation_11.1.zip
```

* Install DB2 using th wizard, take special notes of the user and password used for the db2 instance
```
#cd server_awse_o
#./db2setup
```

* Apply the db2 licence for the installation
```
#cd /opt/ibm/db2/V11.1/adm
#./db2licm -a {$INSTALLER_DIRECORY}/awse_o/db2/license/db2awse_o.lic

