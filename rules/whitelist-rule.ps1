Import-Module "$PSScriptRoot\Alert-Module.psm1" -Force

# ---------------------- Script Configuration ----------------------

$ruleName = "Unknown user"
$ruleType = "whitelist"

$runEvery = 1 # Script runs every x minute(s). Set to 1 for testing purpose
$alertInterval = 15 # silence alerts within x minutes from previous alerts. Set to 0 for testing purpose
                   # Delete the cache folder whenever this setting is changed
$maxAlertInterval = 60 # maximum minutes to silence exponential alerts. Set to 0 to disable this feature.
                       # $alertInterval will be doubled when $elapsedTime < ($alertInterval * 2) till 
                       # it reaches $maxAlertInterval

$offSchedules = "" # [array] No alert during specified schedules

$bufferTime = 2 # search for data within x minute(s) from $runTime. The time frame in ES query must be manually updated

# Notification settings
$emailEnabled = $true  # $true/$false
$alertLevel = "warning"

# Comma-separated Emails
$recipients = "admin@example.com", "admin_2@example.com"

# Log settings
$logRotation = $true

# Misc configuration
$whitelist = "admin", "root"
$ignoredTerms = "" # Ignore specified terms

# Elasticsearch query configuration
$indexPrefix = "logstash_syslog-"
$indexTimeString = (Get-Date -UFormat '%Y.*%V')
$serverAddr = "192.168.1.10:9200"
$esUrl = "http://$serverAddr/$indexPrefix$indexTimeString/_search"

## Query body
$requestBody = @"
{
  "size": 0,
  "query": {
    "filtered": {
      "filter": {
        "bool": {
          "must": [
            {
              "query": {
                "match": {
                  "type": {
                    "query": "syslog",
                    "type": "phrase"
                  }
                }
              }
            },
            {
              "range": {
                "@timestamp": {
                  "gte": "now-$($bufferTime)m",
                  "lte": "now"
                }
              }
            }
          ],
          "must_not": []
        }
      }
    }
  },
  "aggs": {
    "terms_agg": {
      "terms": {
        "field": "username",
        "size": 100,
        "order": {
          "_count": "desc"
        }
      }
    }
  }
}
"@

# ---------------------- Script Implementation ----------------------

# Check script runtime interval
$runTime = Get-Date
If ( ($runTime.Minute % $runEvery) -ne 0 ) {
    "Wrong runtime interval. Script exits"
    Exit
}

Invoke-LogRotation # depends on $logRotation

# Query against Elasticsearch and process response
## Execute Elasticsearch query
$esResponse = Invoke-RestMethod -URI $esUrl -TimeoutSec 60 -Method Post -ContentType 'application/json' -Body $requestBody

## Process response
$esResponse.aggregations.terms_agg.buckets.GetEnumerator() | foreach {    
    $Term = $_.Key
    $Value = [int]($_.doc_count)
        
    If ($Term -notin $whitelist -and (Test-AlertAttempt -Term $Term -Value $Value) -eq "True") {
        Write-Warning "$Term : $Value"
        Send-Email
    }
}
