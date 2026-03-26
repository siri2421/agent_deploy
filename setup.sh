#!/bin/bash
# Mandatory Prefix

echo "STARTUP-SCRIPT START" 

# variable initialization
export PROJECT_ID=$(gcloud config get-value project) && \
export ZONE=$(gcloud compute project-info describe \
--format="value(commonInstanceMetadata.items[google-compute-default-zone])") && \
export REGION=$(gcloud compute project-info describe \
--format="value(commonInstanceMetadata.items[google-compute-default-region])") && \
export ACTUAL_MCP_URL=$(gcloud run services describe mcp-weather-v1 \
    --format='value(status.url)' \
    --region=us-central1 \
    --quiet) && \
# Download and update some files from demand-promo-agent repo static-assets bucket
gcloud storage cp gs://$PROJECT_ID-static-assets-bucket/demand-promo-agent.zip . && \
unzip demand-promo-agent.zip && \
rm demand-promo-agent.zip && \
cd ~/agent_deploy/demand-promo-agent && \
sed -i "s/adkprj1/$PROJECT_ID/g" ~/agent_deploy/demand-promo-agent/promo-agent/multi_agent/.env && \
sed -i "s|https://mcp-weather-v1-32443485880.us-central1.run.app|$ACTUAL_MCP_URL|g" ~/agent_deploy/demand-promo-agent/promo-agent/multi_agent/.env && \


# Deploy Agent Engine instance
cd ~/agent_deploy/demand-promo-agent/promo_agent 


# craete deploy_remote python file to deploy agent
export PROMO_SA="promo-agent-sa@$PROJECT_ID.iam.gserviceaccount.com"
export STAGING_BUCKET="agent-staging-bucket-$PROJECT_ID"


#sudo apt update && sudo apt install python3-venv -y && \
pip install -r deploy/requirements.txt
python deploy/deploy_remote.py



sleep 30 && \
echo "generate traffic"
python traffic_gen.py