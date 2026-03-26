#!/bin/bash
# Mandatory Prefix
echo "STARTUP-SCRIPT START" 

# 1. Variable initialization
export PROJECT_ID=$(gcloud config get-value project)
export ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-region])")

# Fetch Cloud Run URL
export ACTUAL_MCP_URL=$(gcloud run services describe mcp-weather-v1 \
    --format='value(status.url)' \
    --region=us-central1 \
    --quiet)

# 2. Download and extract
# Using -o for unzip to ensure it doesn't hang asking to overwrite files
gcloud storage cp gs://$PROJECT_ID-static-assets-bucket/demand-promo-agent.zip .
unzip -o demand-promo-agent.zip
rm demand-promo-agent.zip

# 3. Environment Setup
cd ~/agent_deploy/demand-promo-agent || exit
ENV_FILE="./promo-agent/multi_agent/.env" 

if [ -f "$ENV_FILE" ]; then
    sed -i "s/adkprj1/$PROJECT_ID/g" "$ENV_FILE"
    sed -i "s|https://mcp-weather-v1-32443485880.us-central1.run.app|$ACTUAL_MCP_URL|g" "$ENV_FILE"
    echo ".env updated successfully."
else
    echo "ERROR: .env file not found at $ENV_FILE"
fi # <--- This was missing!

# 4. Deploy Agent Engine instance
# Ensure we are in the correct sub-directory for deployment
cd ~/agent_deploy/demand-promo-agent/promo-agent || exit

export PROMO_SA="promo-agent-sa@$PROJECT_ID.iam.gserviceaccount.com"
export STAGING_BUCKET="agent-staging-bucket-$PROJECT_ID"

# 5. Install and Run
# Added --user to pip install to avoid permission issues in some environments
pip install -r deploy/requirements.txt --user
python3 deploy/deploy_remote.py

# 6. Traffic Generation
sleep 30
echo "generate traffic"
python3 traffic_gen.py