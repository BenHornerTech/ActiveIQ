# ActiveIQ API

This is a repository for me to keep my various experimental scripts based upon the NetApp ActiveIQ API:

https://activeiq.netapp.com/api

NetApp ActiveIQ provides a wealth of data for deployed NetApp storage systems and the API provides an ability for users of the platform to build custom reporting capabilities for analysis of these systems.

## Scripts available in this repository

[Node Performance](AIQ-Node-Performance.ps1)
This script takes a NetApp ONTAP cluster name, gathers details for all nodes within that cluster and presents the CPU and peak performance figures for each node with recomended actions.  The time period for analysis is specfied by the user with a minimum recomendation of 1 month.

## Credits

Many thanks to [Adrian Bronder](https://github.com/AdrianBronder) for his initial code for authentication against the ActiveIQ API.

Also thanks to [Carl Granfelt](https://github.com/carlgranfelt) for his assistance in script requirements and code testing.

## Comments

If you have any questions or comments feel free to get in touch or raise an issue.