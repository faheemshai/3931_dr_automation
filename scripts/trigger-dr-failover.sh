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
echo -e "${YELLOW}[*] Scanning for primary VSIs with tags: project:${STUDENT_ID}, env:${ENVIRONMENT}, dr-role:primary...${NC}"

# Get instances as JSON and filter
INSTANCES_JSON=$(ibmcloud is instances --output JSON 2>/dev/null)
if [ $? -ne 0 ] || [ -z "$INSTANCES_JSON" ]; then
    echo -e "${RED}[ERROR] Failed to retrieve VSIs from IBM Cloud.${NC}"
    exit 1
fi

# Extract IDs of matching running instances
MATCHING_IDS=$(echo "$INSTANCES_JSON" | jq -r --arg project "project:${STUDENT_ID}" --arg env "env:${ENVIRONMENT}" '.[] | select(.status == "running" and (.tags | contains([$project, $env, "dr-role:primary"]))) | .id')

if [ -z "$MATCHING_IDS" ] || [ "$MATCHING_IDS" == "null" ]; then
    echo -e "${GREEN}[✓] No running primary VSIs found matching the tags. Already stopped or not deployed.${NC}"
    exit 0
fi

echo -e "${RED}[!] DISASTER SIMULATION DETECTED! Stopping the following primary VSIs in ${REGION}:${NC}"
for ID in $MATCHING_IDS; do
    NAME=$(echo "$INSTANCES_JSON" | jq -r --arg id "$ID" '.[] | select(.id == $id) | .name')
    echo -e "    - ${NAME} (${ID})"
done

# Stop the instances
for ID in $MATCHING_IDS; do
    echo -e "${YELLOW}[*] Issuing stop command for VSI ${ID}...${NC}"
    ibmcloud is instance-stop -f "$ID" &>/dev/null
    if [ $? -eq 0 ]; then
         echo -e "${GREEN}[✓] Stop command sent successfully to VSI ${ID}.${NC}"
    else
         echo -e "${RED}[WARNING] Failed to stop VSI ${ID}.${NC}"
    fi
done

echo -e "${GREEN}[✓] Disaster simulation trigger completed. Primary region ${REGION} workload disrupted.${NC}"
echo -e "${BLUE}======================================================================${NC}"
