# esalert
A simple Elasticsearch alert tool written in Powershell. Inspired by ElastAlert at https://github.com/Yelp/elastalert

## Why?
My idea is to use Powershell script to query data on Elasticsearch and act on the responses. It should be simple enough so that anyone with basic Powershell and Elasticsearch knowledge can create a rule within 1 to 5 minutes.

## What?
### Process
1. Create and test an ES query in Sense/Developer Tool
2. Copy the query into a Powershell script template. Each script is a rule.
3. Test if it works as expected

### Components
1. Windows Task Scheduler
2. Powershell v4 or later
    * A module to handle alert methods, alert suppression, and other minor features
    * Multiple rule templates (count, average, spike, whitelist, blacklist, flatline, frequency, etc.)
3. Sense/Developer Tool in Kibana or anything you prefer to create query.
