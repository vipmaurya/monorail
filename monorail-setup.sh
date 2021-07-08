#!/bin/bash

## ///Configure virtual machine for build process
if [ -f monorail-git-clone-process-completed.log ]; then	
	echo "Depot_Tools setup is ready...continueing to next section"
	else
        sudo apt-get install wget automake make g++ python-mysqldb python-dev git
        sudo apt install mysql-client-core-5.7 -y
        git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
        mkdir monorail_local 
        echo "export PATH=/home/$USER/depot_tools:$PATH" | cat >> ~/.bashrc 
        source ~/.bashrc
        cd monorail_local; /home/al16-vipin/depot_tools/fetch infra ;cd infra
        echo "Depot Tools setup is ready." >> monorail-depot_tools-setup-completed.log
        echo "Depot tool setup is ready."
fi

if [ -f monorail-git-clone-process-completed.log ]; then	
	echo "monorail project is already cloned...continueing to next section"
	else
        echo "Provide your github account credentials "
        read -p 'GIT_USER:' GIT_USER
        read -p 'GIT_PASSWORD:' GIT_PASSWORD
        read -p 'GIT_REPO:' GIT_REPO

        git clone https://$GIT_USER:$GIT_PASSWORD@github.com/$GIT_USER/$GIT_REPO.git
        echo "monorail project is cloned successfully." >> monorail-git-clone-process-completed.log
        echo "monorail project is cloned."
fi

mv monorail/* /home/$USER/monorail_local/infra/appengine/monorail/

## /// Setup your virtual monorail dev environment and grant permissions

if [ -f python-virtual-environment-completed.log ]; then	
	echo "monorail python virtual environment is already created ...continueing to next section"
	else
        cd /home/$USER/monorail_local/infra/appengine/monorail/; eval `../../go/env.py`
        chmod -R 755 ~/.vpython-root/
        curl https://bootstrap.pypa.io/pip/2.7/get-pip.py --output get-pip.py
        sudo python get-pip.py
        sudo `which python` `which pip` install six
        echo "monorail python virtual environment is ready." >> python-virtual-environment-completed.log
        echo "monorail python virtual environment is ready."
fi
read -p 'INSTANCE_NAME:' INSTANCE_NAME
read -p 'PROJECT_NAME:' PROJECT_NAME
read -p 'PROJECT_ID:' PROJECT_ID

 # Setup Project id for this instance       
if [ -f Gcloud-login-completed.log ]; then	
	echo "You are already loged in to gcloud project $PROJECT_NAME ...continueing to next section"
	else
        gcloud auth login
        
        gcloud config set project $PROJECT_ID
        echo "Gcloud log in sucessful." >> Gcloud-login-completed.log
        echo "Gcloud log in sucessful."
fi

    INSTANCE_IP=$(gcloud compute instances describe $INSTANCE_NAME --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

##Setup mysql Database for monorail

if [ -f SQL-instance-completed.log ]; then	
	echo "You are already created SQL instance in project $PROJECT_NAME ...continueing to next section"
	else

         gcloud sql instances create monorail \
            --database-version=MYSQL_5_6 \
            --cpu=1 \
            --memory=3840MB \
            --region=asia-south1 \
            --storage-size=10GB \
            --availability-type=zonal \
            --authorized-networks=$INSTANCE_IP/32 
        
        DBIP=$(gcloud sql instances describe $SQL_INSTANCE_NAME --format="value(ipAddresses.ipAddress)")
        
        mysql --user=root -h $DBIP -e 'CREATE DATABASE monorail;'
        mysql --user=root -h $DBIP monorail < schema/framework.sql
        mysql --user=root -h $DBIP monorail < schema/project.sql
        mysql --user=root -h $DBIP monorail < schema/tracker.sql
        echo "SQL instance is created successfully...." >> SQL-instance-completed.log
        echo "SQL instance is created successfully....!!!."
fi        

# Creating app Engine 
if [ -f APP-Engine-completed.log ]; then	
	echo "You are already created APP Engine in project $PROJECT_NAME ...continueing to next section"
	else     
        echo "Creating app in $PROJECT_NAME"
        gcloud app create
        echo "App Engine is created successfully..." >> APP-Engine-completed.log
        echo "App Engine is  created successfully....!!!."
fi               

echo Please wait for 240 Seconds still creating 
sleep 240
##/// After created bucket we need to give permissons to use resources

if [ -f Bucket-permissions-completed.log ]; then	
	echo "You are already given permissions to bucket in project $PROJECT_NAME ...continueing to next section"
	else


        SERVICE_ACCOUNT_NUMBER=$(gcloud iam service-accounts list | awk 'NR==3 {print $6}' | sed 's/-.*//')
        read -p 'PROJECT_ID:' PROJECT_ID
        gsutil iam ch serviceAccount:$SERVICE_ACCOUNT_NUMBER@cloudbuild.gserviceaccount.com:roles/firebase.viewer gs://staging.$PROJECT_ID.appspot.com
        gsutil iam ch serviceAccount:$SERVICE_ACCOUNT_NUMBER@cloudbuild.gserviceaccount.com:roles/cloudbuild.serviceAgent gs://staging.$PROJECT_ID.appspot.com
        gsutil iam ch serviceAccount:$SERVICE_ACCOUNT_NUMBER@cloudbuild.gserviceaccount.com:roles/cloudbuild.builds.builder gs://staging.$PROJECT_ID.appspot.com
        gsutil iam ch serviceAccount:$SERVICE_ACCOUNT_NUMBER@cloudbuild.gserviceaccount.com:roles/cloudfunctions.serviceAgent gs://staging.$PROJECT_ID.appspot.com
        gsutil iam ch serviceAccount:$SERVICE_ACCOUNT_NUMBER@cloudbuild.gserviceaccount.com:roles/containerregistry.ServiceAgent gs://staging.$PROJECT_ID.appspot.com
        gsutil iam ch serviceAccount:$SERVICE_ACCOUNT_NUMBER@cloudbuild.gserviceaccount.com:roles/firebase.sdkAdminServiceAgent gs://staging.$PROJECT_ID.appspot.com
        gsutil iam ch serviceAccount:$SERVICE_ACCOUNT_NUMBER@cloudbuild.gserviceaccount.com:roles/firebase.managementServiceAgent gs://staging.$PROJECT_ID.appspot.com

        echo "Required Permissions are set to Bucket successfully..." >> Bucket-permissions-completed.log
        echo "Required Permissions are set to Bucket successfully....!!!."
fi  

echo "Please wait for 120 seconds doing last checkup....." 
sleep 120
echo "Now Deploying Monorail Please wait.........." 

make deploy_prod

