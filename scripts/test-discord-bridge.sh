#!/bin/bash

BRIDGE_URL="http://localhost:9000"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Starting Discord Bridge Verification Tests...${NC}"

# 1. Test Overseerr Webhook
echo -e "\n${BLUE}Test 1: Overseerr Webhook (Email Mapping)${NC}"
curl -s -X POST "$BRIDGE_URL" \
     -H "Content-Type: application/json" \
     -d '{
       "email": "caleb.john.larsen@gmail.com",
       "subject": "Overseerr Test",
       "message": "This is a simulated Overseerr notification."
     }'
echo -e "\n${GREEN}Check Discord for Overseerr Test DM.${NC}"

# 2. Test Radarr Webhook
echo -e "\n${BLUE}Test 2: Radarr Webhook (Label Mapping)${NC}"
curl -s -X POST "$BRIDGE_URL" \
     -H "Content-Type: application/json" \
     -d '{
       "eventType": "Download",
       "instanceName": "Radarr",
       "movie": { "title": "The Matrix" },
       "tags": ["caleb"]
     }'
echo -e "\n${GREEN}Check Discord for Radarr Test DM (The Matrix).${NC}"

# 3. Test Sonarr Webhook
echo -e "\n${BLUE}Test 3: Sonarr Webhook (Label Mapping)${NC}"
curl -s -X POST "$BRIDGE_URL" \
     -H "Content-Type: application/json" \
     -d '{
       "eventType": "Download",
       "instanceName": "Sonarr",
       "series": { "title": "The Boys" },
       "episode": { "seasonNumber": 1, "episodeNumber": 1 },
       "tags": ["caleb"]
     }'
echo -e "\n${GREEN}Check Discord for Sonarr Test DM (The Boys).${NC}"

echo -e "\n${BLUE}Verification Complete.${NC}"
