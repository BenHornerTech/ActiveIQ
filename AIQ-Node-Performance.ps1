#!/usr/bin/env pwsh

################################################################################################
#
# Title:        AIQ-Node-Performance.ps1
# Author:       Ben Horner
# Date:         2021-05-22
# Description:  Get all nodes from a single cluster UUID and compare
#		        current and peak performance CPU figures
# Thanks:       Thank you to Adrian Bronder for the original API auth code
#               github.com/AdrianBronder
#
# APIs:         /v1/tokens/accessToken
#               /v1/clusterview/resolver
#               /v1/performance-data/graphs
#               /v3/search/aggregate
#
# URLs:         https://mysupport.netapp.com/myautosupport/dist/index.html#/apiservices
#               https://mysupport.netapp.com/myautosupport/dist/index.html#/apidocs/serviceList
#
################################################################################################

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ENDPOINT = "https://api.activeiq.netapp.com"


### Step 1 - Check Credentials
if ( -not (Test-Path .\tokens.json) ){
    @{"access_token"=""; "refresh_token"=""} | ConvertTo-Json | Out-File .\tokens.json
}
$TOKENS = Get-Content -Raw -Path .\tokens.json | ConvertFrom-Json

if ( [string]::IsNullOrEmpty($TOKENS.refresh_token) ){
    $TOKENS.refresh_token = Read-Host -Prompt "Enter your Active IQ API 'REFRESH' token: "
}


### Step 2 - Generate an access token
$API = $ENDPOINT+"/v1/tokens/accessToken"
$HEADERS = @{
    "accept" = "application/json"
    "Content-Type" = "application/json"
}
$POST_DATA = @{
    "refresh_token" = $TOKENS.refresh_token
}

$REST_RESPONSE = Invoke-RestMethod -Uri $API -Headers $HEADERS -Body ($POST_DATA|ConvertTo-Json) -Method POST
$TOKENS.access_token = $REST_RESPONSE.access_token
$TOKENS.refresh_token = $REST_RESPONSE.refresh_token

$TOKENS | ConvertTo-Json | Out-File .\tokens.json
$HEADERS.Add("authorizationToken", $TOKENS.access_token)


### Step 3 - Get cluster name and resolve to cluster UUID
Clear-Host
$SEARCH_CLUSTER_NAME = Read-Host -Prompt "Enter a cluster name"
$START_DATE = Read-Host -Prompt "Start date (YYYY-MM-DD)"
$END_DATE = Read-Host -Prompt "End date (YYYY-MM-DD)"

# Search with given criteria against /v3/search/aggregate API and store results in $REST_SEARCH_RESPONSE
$API_SEARCH = $ENDPOINT+"/v3/search/aggregate?cluster="+$SEARCH_CLUSTER_NAME
$REST_SEARCH_RESPONSE = Invoke-RestMethod -Uri $API_SEARCH -Headers $HEADERS -Method GET

# Store cluster UUID in $CLUSTER_UUID
$CLUSTER_UUID = $REST_SEARCH_RESPONSE.results.id


### Step 4 - Get all node details for provided cluster UUID from /v1/clusterview/resolver API and store results in $REST_RESOLVER_RESPONSE
$API = $ENDPOINT+"/v1/clusterview/resolver/"+$CLUSTER_UUID
$REST_RESOLVER_RESPONSE = Invoke-RestMethod -Uri $API -Headers $HEADERS -Method GET
Clear-Host

### Step 5 - Get performance data for each node within the cluster
$table = @()
$counter = 0
foreach ($node in $REST_RESOLVER_RESPONSE.clusters.nodes ) {
    
    $counter++
    Clear-Host
    Write-host "Found"$REST_RESOLVER_RESPONSE.clusters.nodes.Count"nodes in cluster"$REST_RESOLVER_RESPONSE.clusters.name
    Write-Host "Processing node"$node.name

    # Gather performance data for given node
    $API = $ENDPOINT+"/v1/performance-data/graphs?graphName=node_headroom_cpu_utilization&serialNumber="+$node.serial+"&startDate=$START_DATE&endDate=$END_DATE"
    $REST_RESPONSE = Invoke-RestMethod -Uri $API -Headers $HEADERS -Method GET

    # Extract performance statistics from data returned for each node and store results
    $result_cpu = $REST_RESPONSE.results.counterData.PSObject.Properties.Value | Measure-Object -AllStats -Property current_utilization
    $result_peak = $REST_RESPONSE.results.counterData.PSObject.Properties.Value | Measure-Object -AllStats -Property peak_performance

    # Set advice flags for nodes close to or over peak performance
    $headroom = "Node has headroom available"
    $cpu_variance = "CPU usage is steady"
    if ($result_cpu.Average -gt ($result_peak.Average - 10))
    {
        $headroom = "** Node is over worked **"
    }
    else {
        if ($result_cpu.Average -lt ($result_peak.Average) -and ($result_cpu.Average -ge ($result_peak.Average - 20))) 
        {
            $headroom = "* Node is close to limit *"
        }
    }
    if ($result_cpu.StandardDeviation -gt 4)
    {
        $cpu_variance = "** CPU usage is highly variable **"
    }

    # Place all data into table
    $table += (
        [pscustomobject]@{
            Node_Name=$node.name;Node_Model=$node.model;
            Node_Serial=$node.serial;
            CPU_Utilisation_Average=($result_cpu.Average/100).ToString("P2");
            Peak_Performance_Average=($result_peak.Average/100).ToString("P2");
            Node_Headroom=($headroom);
            Variance=($cpu_variance)}
    )
}

### Step 6 -  Display results
start-sleep 2
Clear-Host
Write-host ""
Write-host "Displaying results for all"$REST_RESOLVER_RESPONSE.clusters.nodes.Count"nodes in cluster"$REST_RESOLVER_RESPONSE.clusters.name
Write-host ""
Write-output $table | Format-Table
Write-host ""