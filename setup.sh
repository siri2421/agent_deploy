#!/bin/bash
# Mandatory Prefix

## Add new comment to test
set -e

echo "STARTUP-SCRIPT START" 

# variable initialization
export PROJECT_ID=$(gcloud config get-value project) && \
export ZONE=$(gcloud compute project-info describe \
--format="value(commonInstanceMetadata.items[google-compute-default-zone])") && \
export REGION=$(gcloud compute project-info describe \
--format="value(commonInstanceMetadata.items[google-compute-default-region])") && \

# Download and update some files from demand-promo-agent repo static-assets bucket
gcloud storage cp gs://$PROJECT_ID-static-assets-bucket/demand-promo-agent.zip . && \
unzip demand-promo-agent.zip && \
rm ~/demand-promo-agent.zip && \
cd ~/demand-promo-agent && \
sed -i -e "s/kar-ai1/$PROJECT_ID/g" ~/demand-promo-agent/variables.tf && \
sed -i -e "s/us-central1-a/$ZONE/g" ~/demand-promo-agent/modules/compute/variables.tf && \
sed -i -e "s/us-central1-a/$ZONE/g" ~/demand-promo-agent/main.tf && \
sed -i -e "s/promo-agent/promo_agent/g" ~/demand-promo-agent/modules/storage/main.tf && \

# Deploy Agent Engine instance
  cd ~/demand-promo-agent/promo_agent 
  #mkdir deploy && \

  # craete deploy_remote python file to deploy agent
  export PROMO_SA="promo-agent-sa@$PROJECT_ID.iam.gserviceaccount.com"
  export STAGING_BUCKET="agent-staging-bucket-$PROJECT_ID"


  sudo apt update && sudo apt install python3-venv -y && \
  python3 -m venv .venv && \
  . .venv/bin/activate && \
  pip install -r deploy/requirements.txt && \
  python deploy/deploy_remote.py && \



sleep 30 && \
echo "generate traffic"
python traffic_gen.py