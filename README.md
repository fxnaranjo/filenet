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
1. Use the file provided in the [ldap](https://github.com/fxnaranjo/filenet/tree/main/ldap) folder on this repo.
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
***
### Preparing the NFS PROVISIONER IN REDHAT OPENSHIFT CLUSTER (ROKS)
#### For this step you must use a terminal console with the oc command line tool installed
#### For this step you must be logged in into REDHAT OPENSHIFT CLUSTER (ROKS)
```
#git clone https://github.com/kubernetes-incubator/external-storage.git kubernetes-incubator
#cd {$REPO_DIRECTORY}/kubernetes-incubator/nfs-client
#oc create namespace openshift-nfs-storage
#oc project openshift-nfs-storage
#NAMESPACE=`oc project -q`
#sed -i'' "s/namespace:.*/namespace: $NAMESPACE/g" ./deploy/rbac.yaml
#sed -i'' "s/namespace:.*/namespace: $NAMESPACE/g" ./deploy/deployment.yaml 
#oc create -f deploy/rbac.yaml
#oc adm policy add-scc-to-user hostmount-anyuid system:serviceaccount:$NAMESPACE:nfs-client-provisioner
#oc create -f deploy/class.yaml 
#oc create -f deploy/deployment.yaml 
```
***
### Preparing the Filenet namespace in REDHAT OPENSHIFT CLUSTER (ROKS)
#### For this step you must use a terminal console with the oc command line tool installed
#### For this step you must be logged in into REDHAT OPENSHIFT CLUSTER (ROKS)
```
#oc new-project filenet

#oc adm policy add-scc-to-user privileged -z ibm-cp4a-operator -n filenet
```

#### You can obtain this key using this procedure:
* Log in to [MyIBM Container Software Library](https://myibm.ibm.com/products-services/containerlibrary) with the IBMid and password that is associated with the entitled software.
* In the Container software library tile, verify your entitlement on the View library page, and then go to Get entitlement key to retrieve the key. 

```
#oc create secret docker-registry ibm-entitlement-key --docker-username=cp --docker-password=<token> --docker-server=cp.icr.io -n filenet
```


* Create de LDAP Secret
```
#oc create secret generic ldap-bind-secret --from-literal=ldapUsername="cn=root" --from-literal=ldapPassword="<password>"
```
* Create de DB2 Secret for GCDB and Object Store Database
```
#oc create secret generic ibm-fncm-secret \
--from-literal=gcdDBUsername="db2inst1" --from-literal=gcdDBPassword="<>password" \
--from-literal=osDBUsername="db2inst1" --from-literal=osDBPassword="<password>" \
--from-literal=appLoginUsername="ceadmin" --from-literal=appLoginPassword="<password>" \
--from-literal=keystorePassword="<password>" \
--from-literal=ltpaPassword="<password>" -n filenet
```
* Create de NAVIGATOR Secret
```
#oc create secret generic ibm-ban-secret \
--from-literal=navigatorDBUsername="db2inst1" \
--from-literal=navigatorDBPassword="<password>" \
--from-literal=keystorePassword="<password>" \
--from-literal=ltpaPassword="<password>" \
--from-literal=appLoginUsername="<user>" \
--from-literal=appLoginPassword="<password>" \
--from-literal=jMailUsername="mailadmin" \
--from-literal=jMailPassword="<password>" -n filenet
```

***
### Installing Filenet using the Cloud Pak for Automation Operator
1. Download the following github repo
```
#git clone https://github.com/icp4a/cert-kubernetes.git
```
2. Run the cluster admin setup script
```
#cd {$REPO_DIRECTORY}/cert-kubernetes/scripts
#./cp4a-clusteradmin-setup.sh 
```
* In this screen select the type of platform, in this case option 1
![Setup1](https://github.com/fxnaranjo/filenet/raw/main/images/1setup.png "Setup1")

* In this step select the type of deployment, in this case option 2
![Setup2](https://github.com/fxnaranjo/filenet/raw/main/images/2setup.png "Setup2")

* Next, enter the name of the namespace to be used for the installation
![Setup3](https://github.com/fxnaranjo/filenet/raw/main/images/3setup.png "Setup3")

* Next, select the user to be used for the installation
![Setup4](https://github.com/fxnaranjo/filenet/raw/main/images/4setup.png "Setup4")

* Next, wait for the script to finish the execution presenting the following screen
![Setup5](https://github.com/fxnaranjo/filenet/raw/main/images/5setup.png "Setup5")

3. Run the operator install and create the Custom Resource Definition
```
#cd {$REPO_DIRECTORY}/cert-kubernetes/scripts
#./cp4a-deployment.sh
```
* Accept the licence
![Opp1](https://github.com/fxnaranjo/filenet/raw/main/images/1operator.png "Operator5")

* Enter either New or Existing installation, in this case New(1)
![Opp2](https://github.com/fxnaranjo/filenet/raw/main/images/2operator.png "Operator2")

* Enter the option to use OLM, in this case No
![Opp3](https://github.com/fxnaranjo/filenet/raw/main/images/3operator.png "Operator3")

* In this step select the type of deployment, in this case option 2
![Setup2](https://github.com/fxnaranjo/filenet/raw/main/images/2setup.png "Setup2")

* In this screen select the type of platform, in this case option 1
![Setup1](https://github.com/fxnaranjo/filenet/raw/main/images/1setup.png "Setup1")

* Select the component of the cloud pak to be installed, in this case option 1
![Opp4](https://github.com/fxnaranjo/filenet/raw/main/images/4operator.png "Operator4")

* In the next screen just hit ENTER because no additional components will be installed
![Opp5](https://github.com/fxnaranjo/filenet/raw/main/images/5operator.png "Operator5")

* Next, you must select the features of filnet to be installed, just hit ENTER because no additional features will be required. By default cpe,graphql and navigator are installed
![Opp6](https://github.com/fxnaranjo/filenet/raw/main/images/6operator.png "Operator6")

* Next, indicate that you already have an Entitlement Registry key
![Opp7](https://github.com/fxnaranjo/filenet/raw/main/images/7operator.png "Operator7")

* Next, enter the Entitlement Registry key
![Opp8](https://github.com/fxnaranjo/filenet/raw/main/images/8operator.png "Operator8")

* Next, enter the Cluster hostname
![Opp9](https://github.com/fxnaranjo/filenet/raw/main/images/9operator.png "Operator9")

* Next, enter the Storage class to be used, in this case: managed-nfs-storage
![Opp10](https://github.com/fxnaranjo/filenet/raw/main/images/10operator.png "Operator10")

* Next, enter the type of LDAP to be used, in this case: Tivoli Directory Server / Security Directory Server
![Opp11](https://github.com/fxnaranjo/filenet/raw/main/images/11operator.png "Operator11")

* Next, enter the number of Object Stores to be created, in this case one
![Opp12](https://github.com/fxnaranjo/filenet/raw/main/images/12operator.png "Operator12")

* Next, review the summary and type Yes to continue with the operator deployment
![Opp13](https://github.com/fxnaranjo/filenet/raw/main/images/13operator.png "Operator13")

* Review the openshift web console until the operator is up and running
![Opp14](https://github.com/fxnaranjo/filenet/raw/main/images/14operator.png "Operator14")

4. Deploy Filenet Custom Resource Definition
* The prior procedure creates a file in {$REPO_DIRECTORY}/cert-kubernetes/scripts/generated-cr called ibm_cp4a_cr_final.yaml, to deploy filenet you have to edit this file in order to include your environment properties.

* The following [file](https://github.com/fxnaranjo/filenet/tree/main/cr) can be used as an example.

* Once the file is ready you can deploy filenet using the following command:
```
#cd {$REPO_DIRECTORY}/cert-kubernetes/scripts/generated-cr/
#oc apply -f ibm_cp4a_cr_final.yaml
```
* Review the openshift web console until all pods are up and running: 2 cpe, 2 graphql , 2 navigator
![Deploy1](https://github.com/fxnaranjo/filenet/raw/main/images/1deploy.png "Deploy1")

* Once the deployment is completed run the following script for final validation
```
#cd {$REPO_DIRECTORY}/cert-kubernetes/scripts/
#./cp4a-post-deployment.sh
```
* The screen will show the URLs for both ACCE and Navigator
![Deploy2](https://github.com/fxnaranjo/filenet/raw/main/images/2deploy.png "Deploy2")

***
***
***
# Congratulations!!, Filenet is now ready to use














