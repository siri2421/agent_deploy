#!/bin/bash
echo "STARTUP-SCRIPT START" 

# 1. Variable initialization
export PROJECT_ID=$(gcloud config get-value project)
export ACTUAL_MCP_URL=$(gcloud run services describe mcp-weather-v1 \
    --format='value(status.url)' \
    --region=us-central1 \
    --quiet)

export FULL_MCP_ENDPOINT="${ACTUAL_MCP_URL}/mcp/"

# 2. Download and extract
gcloud storage cp gs://$PROJECT_ID-static-assets-bucket/demand-promo-agent.zip .
unzip -o demand-promo-agent.zip
rm demand-promo-agent.zip

# 3. Environment Setup (Fixing the path to promo_agent)
cd ~/agent_deploy/demand-promo-agent || exit

# Use the underscore here based on your 'ls' output
ENV_FILE="./promo_agent/multi_agent/.env" 

if [ -f "$ENV_FILE" ]; then
    sed -i "s/adkprj1/$PROJECT_ID/g" "$ENV_FILE"
    sed -i "s|https://mcp-weather-v1-.*\.run\.app/mcp/|$FULL_MCP_ENDPOINT|g" "$ENV_FILE"
    sed -i "s|https://mcp-weather-v1-.*\.run\.app|$ACTUAL_MCP_URL|g" "$ENV_FILE"
    echo ".env updated successfully."
else
    echo "ERROR: .env file not found at $ENV_FILE"
fi

# 4. Deploy Agent Engine instance
# Navigate to the folder containing deploy/ and traffic_gen.py
cd ~/agent_deploy/demand-promo-agent/promo_agent || exit

export PROMO_SA="promo-agent-sa@$PROJECT_ID.iam.gserviceaccount.com"
export STAGING_BUCKET="agent-staging-bucket-$PROJECT_ID"

# 5. Install and Run
pip install -r deploy/requirements.txt
python3 deploy/deploy_remote.py

# 6. Traffic Generation
sleep 30
echo "Generating traffic..."
python3 traffic_gen.py

# Get agent engine deployment ID
REASONING_ENGINE_DEPLOYMENT_ID=$(curl -X GET "https://aiplatform.googleapis.com/v1/projects/$PROJECT_ID/locations/$REGION/reasoningEngines"     -H "Authorization: Bearer $(gcloud auth print-access-token)" | jq -r '.? | .reasoningEngines[].name') && \
echo "Agent Engine Resource ID: $REASONING_ENGINE_DEPLOYMENT_ID"

# Integrate Agent Engine instance into Gemini Enterprise
curl -X POST \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -H "X-Goog-User-Project: ${PROJECT_ID}" \
  "https://discoveryengine.googleapis.com/v1alpha/projects/${PROJECT_ID}/locations/global/collections/default_collection/engines/promotion-agent-demo/assistants/default_assistant/agents" \
  -d @- <<EOF
{
  "displayName": "Promotion Agent",
  "description": "Creates promotions for retail products based on local events and weather in a particular US city.",
  "adk_agent_definition": {
    "tool_settings": {
      "tool_description": "You are a promotional agent for retail stores. Your task is to create promotions for retail products based on local events and weather in a particular US city."
    },
    "provisioned_reasoning_engine": {
      "reasoning_engine": "${REASONING_ENGINE_DEPLOYMENT_ID}"
    }
  }
}
EOF