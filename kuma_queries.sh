#!/bin/bash
###########################################################################
# Import/Export KUMA Queries v.1 (14.05.2024)
###########################################################################

RED='\033[0;31m'
NC='\033[0m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'

###########################################################################

KUMA_VER=$(/opt/kaspersky/kuma/kuma version)

###########################################################################
# Usage description

USAGE="${GREEN}$(basename "$0") [-h] [-import] [-export] <OPTIONS>\n
${BLUE}EXAMPLES:\n
${YELLOW}$(basename "$0") -h${NC}\t\t\t\t\thelp\n
${YELLOW}$(basename "$0") -import <FILENAME>${NC}\t\t\timport saved queries from JSON-file (e.g. saved_queries.json)\n
${YELLOW}$(basename "$0") -import <FILENAME> <CONFIG FILE>${NC}\timport saved queries from JSON-file for products specified in config file (e.g. saved_queries.json product_list.cfg)\n
${YELLOW}$(basename "$0") -export${NC}\t\t\t\texport saved queries to the script directory\n
${YELLOW}$(basename "$0") -export <DIRECTORY>${NC}\t\t\texport saved queries to the specific directory (e.g. /tmp)
"

###########################################################################
# No arguments

if [ $# -eq 0 ]; then
    echo -e "${RED}ERROR!${NC}No arguments specified"
    echo -e $USAGE
    exit 1
fi

###########################################################################
# Import/Export queries

case $1 in
    
    # Help output
    "-h")
    echo -e $USAGE
    ;;
    
    # Export all saved queries
    "-export")
    # KUMA v3.0
    if [[ $KUMA_VER =~ ^3\.0 ]] && [[ -z $2 ]]; then
        /opt/kaspersky/kuma/mongodb/bin/mongo localhost/kuma --quiet --eval 'db.resources.find({"kind":"search"}).forEach(function(f){print(tojson(f, "", true));});' > $PWD/kuma-saved-queries_$(date +"%d%m%Y-%H%M").json
        echo -e "${GREEN}Queries saved to the file $PWD/kuma-saved-queries_$(date +"%d%m%Y-%H%M").json"
    elif [[ $KUMA_VER =~ ^3\.0 ]] && [ -d $2 ]; then
        /opt/kaspersky/kuma/mongodb/bin/mongo localhost/kuma --quiet --eval 'db.resources.find({"kind":"search"}).forEach(function(f){print(tojson(f, "", true));});' > $2/kuma-saved-queries_$(date +"%d%m%Y-%H%M").json
        echo -e "${GREEN}Queries saved to the file $2/kuma-saved-queries_$(date +"%d%m%Y-%H%M").json"
    # KUMA v2.1
    elif [[ $KUMA_VER =~ ^2\.1 ]] && [[ -z $2 ]]; then
        /opt/kaspersky/kuma/mongodb/bin/mongo localhost/kuma --quiet --eval 'db.resources.find({"kind":"search"}).forEach(function(f){print(tojson(f, "", true));});' > $PWD/kuma-saved-queries_$(date +"%d%m%Y-%H%M").json
        echo -e "${GREEN}Queries saved to the file $PWD/kuma-saved-queries_$(date +"%d%m%Y-%H%M").json"
    elif [[ $KUMA_VER =~ ^2\.1 ]] && [ -d $2 ]; then
        /opt/kaspersky/kuma/mongodb/bin/mongo localhost/kuma --quiet --eval 'db.resources.find({"kind":"search"}).forEach(function(f){print(tojson(f, "", true));});' > $2/kuma-saved-queries_$(date +"%d%m%Y-%H%M").json
        echo -e "${GREEN}Queries saved to the file $2/kuma-saved-queries_$(date +"%d%m%Y-%H%M").json"
    # ERRORS
    elif [[ ! $KUMA_VER =~ ^2\.1|3\.0 ]]; then
        echo -e "${RED}ERROR!${NC} Unsupported KUMA version. Sorry!"
    else
        echo -e "${RED}ERROR!${NC} The specified directory does not exist"
    fi
    ;;

    # Import queries
        "-import")
    if [[ -z $2 ]]; then
        echo -e "${RED}ERROR!${NC} Which queries should I import? JSON-file not specified"
    elif [[ ! $KUMA_VER =~ ^2\.1|3\.0 ]]; then
        echo -e "${RED}ERROR!${NC} Unsupported KUMA version. Sorry!"
    # KUMA v3.0
    elif [[ $KUMA_VER =~ ^3\.0 ]] && [[ -f $2 ]] && [[ -z $3 ]]; then
        TMP_JSON=$(mktemp)
        ACTUAL_TENANT_ID=$(/opt/kaspersky/kuma/mongodb/bin/mongo localhost/kuma --quiet --eval 'db.tenants.find({"main":true})[0]._id')
        ACTUAL_DATE=$(date +"%s000")
        ACTUAL_ADMIN_ID=$(/opt/kaspersky/kuma/mongodb/bin/mongo localhost/kuma --quiet --eval 'db.standalone_users.find({"login":"admin"})[0]._id')
        ACTUAL_CLUSTER_ID=$(/opt/kaspersky/kuma/mongodb/bin/mongo localhost/kuma --quiet --eval 'db.services.find({"kind": "storage", "status": "green", "tenantID": "'$ACTUAL_TENANT_ID'"})[0].resourceID')
        ALL_IDs=$(/opt/kaspersky/kuma/mongodb/bin/mongo localhost/kuma --quiet --eval 'db.resources.find({},{_id:1}).forEach(function(f){print(tojson(f, "", true));});' | awk '{gsub(/"/, "", $4);print $4}')
        cp $2 "$TMP_JSON"
        sed -i 's/NumberLong("*\([0-9]*\)"*)/\1/g' "$TMP_JSON"
        sed -i 's/\\*r*\\n/ /g' "$TMP_JSON"
        while IFS= read -r line; do
            while true; do
                UUID=$(uuidgen)
                UNIQUE_UUID=true
                for string in $ALL_IDs; do
                    if [[ $UUID == $string ]]; then
                        UNIQUE_UUID=false
                        break
                    fi
                done
                if [[ $UNIQUE_UUID == false ]]; then
                    echo "New value $UUID matches one of the existing UUID. Generating new value and checking again."
                else
                    break
                fi
            done
            PREPARED_QUERY=$(echo -e -n "$line" | jq -c --arg UUID "$UUID" --arg ACTUAL_TENANT_ID "$ACTUAL_TENANT_ID" --arg ACTUAL_DATE "$ACTUAL_DATE" --arg ACTUAL_ADMIN_ID "$ACTUAL_ADMIN_ID" --arg ACTUAL_CLUSTER_ID "$ACTUAL_CLUSTER_ID" '._id = $UUID | .exportID = $UUID | .payload.id = $UUID | .tenantID = $ACTUAL_TENANT_ID | .createdAt = ($ACTUAL_DATE | tonumber) | .updatedAt = ($ACTUAL_DATE | tonumber) | .userID = $ACTUAL_ADMIN_ID | .payload.clusterID = $ACTUAL_CLUSTER_ID')
            /opt/kaspersky/kuma/mongodb/bin/mongo localhost/kuma --quiet --eval 'db.resources.insertOne('"$PREPARED_QUERY"');'
        done < "$TMP_JSON"
        if [[ $? == 0 ]]; then
            echo -e "${GREEN}All queries were imported successfully${NC}" 
        else
            :
        fi
    elif [[ $KUMA_VER =~ ^3\.0 ]] && [[ -f $2 ]] && [[ -f $3 ]]; then
        TMP_JSON=$(mktemp)
        ACTUAL_TENANT_ID=$(/opt/kaspersky/kuma/mongodb/bin/mongo localhost/kuma --quiet --eval 'db.tenants.find({"main":true})[0]._id')
        ACTUAL_DATE=$(date +"%s000")
        ACTUAL_ADMIN_ID=$(/opt/kaspersky/kuma/mongodb/bin/mongo localhost/kuma --quiet --eval 'db.standalone_users.find({"login":"admin"})[0]._id')
        ACTUAL_CLUSTER_ID=$(/opt/kaspersky/kuma/mongodb/bin/mongo localhost/kuma --quiet --eval 'db.services.find({"kind": "storage", "status": "green", "tenantID": "'$ACTUAL_TENANT_ID'"})[0].resourceID')
        ALL_IDs=$(/opt/kaspersky/kuma/mongodb/bin/mongo localhost/kuma --quiet --eval 'db.resources.find({},{_id:1}).forEach(function(f){print(tojson(f, "", true));});' | awk '{gsub(/"/, "", $4);print $4}')
        cp $2 "$TMP_JSON"
        sed -i 's/NumberLong("*\([0-9]*\)"*)/\1/g' "$TMP_JSON"
        sed -i 's/\\*r*\\n/ /g' "$TMP_JSON"
        while IFS= read -r line; do
            if [[ $line =~ false$ ]]; then
                PRODUCT=$(echo $line | awk '{gsub(/:/, "", $1);print $1}')
                sed -i "/\"name\" : \"$PRODUCT/d" "$TMP_JSON"
            else
                :
            fi
        done < $3
        while IFS= read -r line; do
            while true; do
                UUID=$(uuidgen)
                UNIQUE_UUID=true
                for string in $ALL_IDs; do
                    if [[ $UUID == $string ]]; then
                        UNIQUE_UUID=false
                        break
                    fi
                done
                if [[ $UNIQUE_UUID == false ]]; then
                    echo "New value $UUID matches one of the existing UUID. Generating new value and checking again."
                else
                    break
                fi
            done
            PREPARED_QUERY=$(echo -e -n "$line" | jq -c --arg UUID "$UUID" --arg ACTUAL_TENANT_ID "$ACTUAL_TENANT_ID" --arg ACTUAL_DATE "$ACTUAL_DATE" --arg ACTUAL_ADMIN_ID "$ACTUAL_ADMIN_ID" --arg ACTUAL_CLUSTER_ID "$ACTUAL_CLUSTER_ID" '._id = $UUID | .exportID = $UUID | .payload.id = $UUID | .tenantID = $ACTUAL_TENANT_ID | .createdAt = ($ACTUAL_DATE | tonumber) | .updatedAt = ($ACTUAL_DATE | tonumber) | .userID = $ACTUAL_ADMIN_ID | .payload.clusterID = $ACTUAL_CLUSTER_ID')
            /opt/kaspersky/kuma/mongodb/bin/mongo localhost/kuma --quiet --eval 'db.resources.insertOne('"$PREPARED_QUERY"');'
        done < "$TMP_JSON"
        if [[ $? == 0 ]]; then
            echo -e "${GREEN}All specified queries were imported successfully${NC}" 
        else
            :
        fi
    # KUMA v2.1
    elif [[ $KUMA_VER =~ ^2\.1 ]] && [[ -f $2 ]] && [[ -z $3 ]]; then
        TMP_JSON=$(mktemp)
        ACTUAL_TENANT_ID=$(/opt/kaspersky/kuma/mongodb/bin/mongo localhost/kuma --quiet --eval 'db.tenants.find({"main":true})[0]._id')
        ACTUAL_DATE=$(date +"%s000")
        ACTUAL_ADMIN_ID=$(/opt/kaspersky/kuma/mongodb/bin/mongo localhost/kuma --quiet --eval 'db.users.find({"login":"admin"})[0]._id')
        ACTUAL_CLUSTER_ID=$(/opt/kaspersky/kuma/mongodb/bin/mongo localhost/kuma --quiet --eval 'db.services.find({"kind": "storage", "status": "green", "tenantID": "'$ACTUAL_TENANT_ID'"})[0].resourceID')
        ALL_IDs=$(/opt/kaspersky/kuma/mongodb/bin/mongo localhost/kuma --quiet --eval 'db.resources.find({},{_id:1}).forEach(function(f){print(tojson(f, "", true));});' | awk '{gsub(/"/, "", $4);print $4}')
        cp $2 "$TMP_JSON"
        sed -i 's/NumberLong("*\([0-9]*\)"*)/\1/g' "$TMP_JSON"
        sed -i 's/\\*r*\\n/ /g' "$TMP_JSON"
        while IFS= read -r line; do
            while true; do
                UUID=$(uuidgen)
                UNIQUE_UUID=true
                for string in $ALL_IDs; do
                    if [[ $UUID == $string ]]; then
                        UNIQUE_UUID=false
                        break
                    fi
                done
                if [[ $UNIQUE_UUID == false ]]; then
                    echo "New value $UUID matches one of the existing UUID. Generating new value and checking again."
                else
                    break
                fi
            done
            PREPARED_QUERY=$(echo -e -n "$line" | jq -c --arg UUID "$UUID" --arg ACTUAL_TENANT_ID "$ACTUAL_TENANT_ID" --arg ACTUAL_DATE "$ACTUAL_DATE" --arg ACTUAL_ADMIN_ID "$ACTUAL_ADMIN_ID" --arg ACTUAL_CLUSTER_ID "$ACTUAL_CLUSTER_ID" '._id = $UUID | .exportID = $UUID | .payload.id = $UUID | .tenantID = $ACTUAL_TENANT_ID | .createdAt = ($ACTUAL_DATE | tonumber) | .updatedAt = ($ACTUAL_DATE | tonumber) | .userID = $ACTUAL_ADMIN_ID | .payload.clusterID = $ACTUAL_CLUSTER_ID')
            /opt/kaspersky/kuma/mongodb/bin/mongo localhost/kuma --quiet --eval 'db.resources.insertOne('"$PREPARED_QUERY"');'
        done < "$TMP_JSON"
        if [[ $? == 0 ]]; then
            echo -e "${GREEN}All queries were imported successfully${NC}" 
        else
            :
        fi
    elif [[ $KUMA_VER =~ ^2\.1 ]] && [[ -f $2 ]] && [[ -f $3 ]]; then
        TMP_JSON=$(mktemp)
        ACTUAL_TENANT_ID=$(/opt/kaspersky/kuma/mongodb/bin/mongo localhost/kuma --quiet --eval 'db.tenants.find({"main":true})[0]._id')
        ACTUAL_DATE=$(date +"%s000")
        ACTUAL_ADMIN_ID=$(/opt/kaspersky/kuma/mongodb/bin/mongo localhost/kuma --quiet --eval 'db.users.find({"login":"admin"})[0]._id')
        ACTUAL_CLUSTER_ID=$(/opt/kaspersky/kuma/mongodb/bin/mongo localhost/kuma --quiet --eval 'db.services.find({"kind": "storage", "status": "green", "tenantID": "'$ACTUAL_TENANT_ID'"})[0].resourceID')
        ALL_IDs=$(/opt/kaspersky/kuma/mongodb/bin/mongo localhost/kuma --quiet --eval 'db.resources.find({},{_id:1}).forEach(function(f){print(tojson(f, "", true));});' | awk '{gsub(/"/, "", $4);print $4}')
        cp $2 "$TMP_JSON"
        sed -i 's/NumberLong("*\([0-9]*\)"*)/\1/g' "$TMP_JSON"
        sed -i 's/\\*r*\\n/ /g' "$TMP_JSON"
        while IFS= read -r line; do
            if [[ $line =~ false$ ]]; then
                PRODUCT=$(echo $line | awk '{gsub(/:/, "", $1);print $1}')
                sed -i "/\"name\" : \"$PRODUCT/d" "$TMP_JSON"
            else
                :
            fi
        done < $3
        while IFS= read -r line; do
            while true; do
                UUID=$(uuidgen)
                UNIQUE_UUID=true
                for string in $ALL_IDs; do
                    if [[ $UUID == $string ]]; then
                        UNIQUE_UUID=false
                        break
                    fi
                done
                if [[ $UNIQUE_UUID == false ]]; then
                    echo "New value $UUID matches one of the existing UUID. Generating new value and checking again."
                else
                    break
                fi
            done
            PREPARED_QUERY=$(echo -e -n "$line" | jq -c --arg UUID "$UUID" --arg ACTUAL_TENANT_ID "$ACTUAL_TENANT_ID" --arg ACTUAL_DATE "$ACTUAL_DATE" --arg ACTUAL_ADMIN_ID "$ACTUAL_ADMIN_ID" --arg ACTUAL_CLUSTER_ID "$ACTUAL_CLUSTER_ID" '._id = $UUID | .exportID = $UUID | .payload.id = $UUID | .tenantID = $ACTUAL_TENANT_ID | .createdAt = ($ACTUAL_DATE | tonumber) | .updatedAt = ($ACTUAL_DATE | tonumber) | .userID = $ACTUAL_ADMIN_ID | .payload.clusterID = $ACTUAL_CLUSTER_ID')
            /opt/kaspersky/kuma/mongodb/bin/mongo localhost/kuma --quiet --eval 'db.resources.insertOne('"$PREPARED_QUERY"');'
        done < "$TMP_JSON"
        if [[ $? == 0 ]]; then
            echo -e "${GREEN}All specified queries were imported successfully${NC}" 
        else
            :
        fi

    fi
    ;;

    * )
    echo -e $USAGE
    ;;
esac