#! /usr/bin/env bash

#################################################################################
# VARIABLES
#################################################################################

username="adminuser"
WORKSPACE="GHR Custom Metrics" 
METRICNAME="GHRJobRunning"
RUNNERNAME=$(hostname)
IMDS=$(curl -s -H Metadata:true "http://169.254.169.254/metadata/instance?api-version=2019-06-01")
LOCATION=$(echo $IMDS | jq -r .compute.location)
RESOURCEID=$(echo $IMDS | jq -r .compute.resourceId | sed 's|/virtualMachines/.*||')
TOKEN=$(curl -s 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fmonitoring.azure.com%2F' -H Metadata:true -s | jq -r .access_token)

#################################################################################
# FUNCTIONS
#################################################################################

function log() {
  logger -p local0.info -t "METRICS" "$1"
  echo "$1" >> /home/$username/metrics.log
}

function post_metrics() {
    # POST a custom metric to Azure Monitor
    http_response=$(curl -s -w "%{http_code}" -X POST https://$LOCATION.monitoring.azure.com$RESOURCEID/metrics -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" --data-binary @- <<EOF
    { 
        "time": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")", 
        "data": { 
            "baseData": { 
                "metric": "$METRICNAME", 
                "namespace": "$WORKSPACE", 
                "dimNames": [ 
                "RunnerName"
                ], 
                "series": [ 
                { 
                    "dimValues": [ 
                    "$RUNNERNAME"
                    ], 
                    "min": $1, 
                    "max": $1, 
                    "sum": $1, 
                    "count": 1
                } 
                ] 
            } 
        } 
    }
EOF
    )

    if [ $http_response != "200" ]; then
        log "Failed to send metric $METRICVAL to Azure Monitor. Server returned $http_response @ $(date)"
    fi
}

#################################################################################
# MAIN
#################################################################################

# every 15s for a minute call post_metrics
# TODO: make this dynamic so we are not forced to every 15s
for i in {1..4}
do
    if [ -f /home/$username/RUNNER_JOB_IN_PROGRESS ]; then
        post_metrics 100
    else
        post_metrics 0
    fi
    sleep 15
done
