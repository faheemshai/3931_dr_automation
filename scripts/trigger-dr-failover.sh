#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# trigger-dr-failover.sh  -  LAB-3931 DR Failover Simulation Trigger
# -----------------------------------------------------------------------------
# Simulates a disaster in us-south by locating and stopping all primary VSIs.
# Scoped strictly to the student's project and environment.
# -----------------------------------------------------------------------------

set -o pipefail

# ANSI color codes for pretty output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}              LAB-3931: DISASTER FAILOVER TRIGGER SIMULATION           ${NC}"
echo -e "${BLUE}======================================================================${NC}"

# Default parameters
STUDENT_ID="lab3931"
REGION="us-south"
ENVIRONMENT="demo"

usage() {
    echo "Usage: $0 --student-id <student_id> --region <region> [--env <env>]"
    echo "  --student-id  The student/project prefix (default: lab3931)"
    echo "  --region      The primary region to disrupt (default: us-south)"
    echo "  --env         The environment label (default: demo)"
    exit 1
}

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --student-id) STUDENT_ID="$2"; shift ;;
        --region) REGION="$2"; shift ;;
        --env) ENVIRONMENT="$2"; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown parameter passed: $1"; usage ;;
    esac
    shift
done

echo -e "${YELLOW}[*] Target Student ID : ${STUDENT_ID}${NC}"
echo -e "${YELLOW}[*] Target Region     : ${REGION}${NC}"
echo -e "${YELLOW}[*] Environment       : ${ENVIRONMENT}${NC}"
echo -e "${YELLOW}[*] Checking IBM Cloud CLI status...${NC}"

# Check for ibmcloud CLI
if ! command -v ibmcloud &> /dev/null; then
    echo -e "${RED}[ERROR] ibmcloud CLI is not installed.${NC}"
    exit 1
fi

# Target region
echo -e "${YELLOW}[*] Setting target region to ${REGION}...${NC}"
ibmcloud target -r "$REGION" &> /dev/null
if [ $? -ne 0 ]; then
    echo -e "${RED}[ERROR] Failed to target region ${REGION}. Are you logged in?${NC}"
    exit 1
fi

# Locate instances matching dr-role:primary, env:ENVIRONMENT and project:STUDENT_ID
# IBM Cloud VPC API does not include tags in ibmcloud is instances output.
# Tags live in the global tagging service — use ibmcloud resource search instead.
echo -e "${YELLOW}[*] Scanning for primary VSIs with tags: project:${STUDENT_ID}, env:${ENVIRONMENT}, dr-role:primary...${NC}"
echo -e "${YELLOW}[*] Querying IBM Cloud global tagging service...${NC}"

SEARCH_RESULT=$(ibmcloud resource search \
    "tags:\"project:${STUDENT_ID}\" AND tags:\"env:${ENVIRONMENT}\" AND tags:\"dr-role:primary\" AND type:instance" \
    --output JSON 2>/dev/null)

if [ $? -ne 0 ] || [ -z "$SEARCH_RESULT" ]; then
    echo -e "${RED}[ERROR] Failed to query IBM Cloud global tagging service.${NC}"
    exit 1
fi

# Extract instance names from the search result
MATCHING_NAMES=$(echo "$SEARCH_RESULT" | jq -r '.items[]? | select(.type == "instance") | .name')

if [ -z "$MATCHING_NAMES" ]; then
    echo -e "${GREEN}[✓] No primary VSIs found matching the tags. Already stopped or not deployed.${NC}"
    exit 0
fi

# Get the full VPC instances list to look up IDs and current status by name
INSTANCES_JSON=$(ibmcloud is instances --output JSON 2>/dev/null)
if [ $? -ne 0 ] || [ -z "$INSTANCES_JSON" ]; then
    echo -e "${RED}[ERROR] Failed to retrieve VPC instance details from IBM Cloud.${NC}"
    exit 1
fi

# Filter to only running instances that match the tagged names
MATCHING_IDS=""
while IFS= read -r VSI_NAME; do
    [ -z "$VSI_NAME" ] && continue
    ID=$(echo "$INSTANCES_JSON" | jq -r --arg name "$VSI_NAME" \
        '.[] | select(.name == $name and .status == "running") | .id')
    if [ -n "$ID" ] && [ "$ID" != "null" ]; then
        MATCHING_IDS="$MATCHING_IDS $ID"
        echo -e "${RED}[!] Found running primary VSI: ${VSI_NAME} (${ID})${NC}"
    else
        STATUS=$(echo "$INSTANCES_JSON" | jq -r --arg name "$VSI_NAME" \
            '.[] | select(.name == $name) | .status')
        echo -e "${YELLOW}[~] VSI ${VSI_NAME} exists but is not running (status: ${STATUS:-not found in region}).${NC}"
    fi
done <<< "$MATCHING_NAMES"

MATCHING_IDS=$(echo "$MATCHING_IDS" | xargs)  # trim whitespace

if [ -z "$MATCHING_IDS" ]; then
    echo -e "${GREEN}[✓] No running primary VSIs found. Already stopped or not deployed.${NC}"
    exit 0
fi

echo -e "${RED}[!] DISASTER SIMULATION: Stopping the following primary VSIs in ${REGION}:${NC}"

# Stop the instances
for ID in $MATCHING_IDS; do
    NAME=$(echo "$INSTANCES_JSON" | jq -r --arg id "$ID" '.[] | select(.id == $id) | .name')
    echo -e "${YELLOW}[*] Issuing stop command for VSI ${NAME} (${ID})...${NC}"
    ibmcloud is instance-stop -f "$ID" &>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[✓] Stop command sent successfully to VSI ${NAME} (${ID}).${NC}"
    else
        echo -e "${RED}[WARNING] Failed to stop VSI ${NAME} (${ID}).${NC}"
    fi
done

echo -e "${GREEN}[✓] Disaster simulation trigger completed. Primary region ${REGION} workload disrupted.${NC}"
echo -e "${BLUE}======================================================================${NC}"
