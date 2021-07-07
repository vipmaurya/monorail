#!/bin/bash

##Installing gcloud sdk

echo "Installing gcloud sdk on local machine..."
if [ -f gcloud-sdk-installed.log ]; then	
	echo "Gcloud SDK Already installed...continueing to next section"
	else
        wget https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-347.0.0-darwin-x86_64.tar.gz
        tar -zxf google-cloud-sdk-347.0.0-darwin-x86_64.tar.gz
        rm -r google-cloud-sdk-347.0.0-darwin-x86_64.tar.gz
        ./google-cloud-sdk/install.sh
        echo "Gcloud SDK installed successfully." >> gcloud-sdk-installed.log
        echo "Gcloud SDK installed successfully."
fi

##Setup gcloud account

if [ -f gcloud-account-setup-completed.log ]; then	
	echo "Gcloud setup is ready...continueing to next section"
	else
        read -p 'ACCOUNT:' ACCOUNT
        gcloud auth login 
        gcloud config set account $ACCOUNT
        echo "Please do not enter old project name"
        read -p 'PROJECT_NAME:' PROJECT_NAME
        read -p 'PROJECT_ID: ' PROJECT_ID
        gcloud projects create $PROJECT_ID --name="$PROJECT_NAME" --labels=type=monorail-bug-tracker

        echo $PROJECT_NAME is created !!!
        gcloud config set project $PROJECT_ID
        
        BILLING_ACCOUNT=$(gcloud alpha billing accounts list | awk 'NR==2 {print $1}')
        gcloud beta billing projects link $PROJECT_ID --billing-account=$BILLING_ACCOUNT
        gcloud compute project-info add-metadata --metadata google-compute-default-region=us-central1,google-compute-default-zone=us-central1-a
        read -p 'INSTANCE_NAME:' INSTANCE_NAME
        echo "Creating VM Instance ....."
        gcloud compute instances create $INSTANCE_NAME --project=$PROJECT_ID \
            --zone=us-central1-a \
            --image=ubuntu-1804-bionic-v20210623 \
            --image-project=ubuntu-os-cloud \
            --machine-type=e2-medium \
            --boot-disk-size=15GB
        echo "Gcloud account setup is ready." >> gcloud-account-setup-completed.log
        echo "Gcloud account setup is ready."
fi

INSTANCE_IP=$(gcloud compute instances describe $INSTANCE_NAME --format='get(networkInterfaces[0].accessConfigs[0].natIP)')


echo "Checking VM Status ,Please be patient will take 120 Seconds"
sleep 120 
echo "Your Gcloud Instance "$INSTANCE_NAME" is created successfully !!!"

#Enabling some important G-cloud API's for project 
echo "Enabling API's for project"
gcloud services enable cloudscheduler.googleapis.com
gcloud services enable cloudtasks.googleapis.com
gcloud services enable iamcredentials.googleapis.com
gcloud services enable cloudbuild.googleapis.com

# Copy monorail-app-engin script to gcloud 
gcloud compute scp monorail-setup.sh $INSTANCE_NAME:~
gcloud compute ssh $INSTANCE_NAME --command="chmod +x monorail-setup.sh"
echo "Now Login to the gcloud instance using below command and then run the monorial script" 
echo "gcloud compute ssh $INSTANCE_NAME"