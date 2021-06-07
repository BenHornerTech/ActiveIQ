# ActiveIQ API

This is a repository for me to keep my various experimental scripts based upon the NetApp ActiveIQ API:

https://activeiq.netapp.com/api

NetApp ActiveIQ provides a wealth of data for deployed NetApp storage systems and the API provides an ability for users of the platform to build custom reporting capabilities for analysis of these systems.

## Scripts available in this repository

[Node Performance](AIQ-Node-Performance.ps1)
This script takes a NetApp ONTAP cluster name, gathers details for all nodes within that cluster and presents the CPU and peak performance figures for each node with recommended actions.  The time period for analysis is specified by the user (in days) with a minimum recommendation of at least 30 days.

```
Displaying results for all 2 nodes in cluster CLUSTER

Node_Name   Node_Model Node_Serial  CPU_Utilisation_Average Peak_Performance_Average Node_Headroom                 Variance
---------   ---------- -----------  ----------------------- ------------------------ -------------                 --------
CLUSTER_N01 AFF8080    211649000287 22.41%                  58.19%                   Node has headroom available   CPU usage is steady
CLUSTER_N02 AFF8080    211649000288 11.82%                  54.95%                   Node has headroom available   * CPU usage is highly variable
```

[Node Performance + FCP](AIQ-Node-FC.ps1)
This script is the same as the Performance script above, but adds an additional flag to highlight any nodes in the cluster that currently deliver FCP IOPS.

```
Displaying results for all 2 nodes in cluster CLUSTER

Node_Name   Node_Model Node_Serial  CPU_Utilisation_Average Peak_Performance_Average Node_Headroom                 Variance                         FCP
---------   ---------- -----------  ----------------------- ------------------------ -------------                 --------                         ---
CLUSTER_N01 AFF8080    211649000287 22.41%                  58.19%                   Node has headroom available   CPU usage is steady              Yes
CLUSTER_N02 AFF8080    211649000288 11.82%                  54.95%                   Node has headroom available   * CPU usage is highly variable   Yes
```

## Credits

Many thanks to [Adrian Bronder](https://github.com/AdrianBronder) for his initial code for authentication against the ActiveIQ API.

Also thanks to [Carl Granfelt](https://github.com/carlgranfelt) for his assistance in script requirements and code testing.

## Comments

If you have any questions or comments feel free to get in touch or raise an issue.