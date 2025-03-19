# Website Resource Usage Monitoring Script for EnhanceCP

## Overview
**Thank you to WebGeeSolutions for intitial script - You rock!!!**
This Bash script retrieves real-time CPU, Memory, and I/O usage for a specific website running in a cgroup-based hosting environment. It provides live statistics, including:
- **Website ID (UUID)**
- **Directory Owner (Linux User)**
- **CPU Usage (%)**
- **Memory Usage (MB and Percentage)**
- **I/O Read, Write, and Total Speed (MB/s)**

## Prerequisites
- The system must support **cgroups v2**.
- The cgroup path should be **`/sys/fs/cgroup/websites/<website_id>`**.
- The script must be executed with appropriate permissions to read cgroup files.

## Installation
1. Copy the script to a directory on your server, such as /root/scripts
2. Give it a name such as website-usage.sh
3. Give it execution permissions:
   ```bash
   chmod +x website-usage.sh
   ```
## Usage
-- To Run the script **interactively** type:
   ```bash
   ./website-usage.sh
   ``` 
- The first prompt will ask if you want to include CPU usage percentage, answer y OR n
   ```bash
   **************************************************************
   *   Do you want to include CPU usage percentage? (y/n)      *
   **************************************************************
   ```
- The next prompt will allow you to select the Search type, 1 for UUID search; 2 for Directory Owner Search, and 3 for List all Sites
      ```bash
      **************************************************************
      *   Please select an option:                                 *
      *                                                            *
      *   Type 1 for UUID Search                                   *
      *   Type 2 for Directory Owner Search                        *
      *   Type 3 to List All Sites                                 *
      *                                                            *
      **************************************************************
      ```
- Make your selection and the search will proceed.

## Command Line Switches
- --UUID uuuid - provide the UUID and this will search for the site UUID
- --OWNER testowner provide the directory owner (i.e. linux user) and this will search and provide information for that Enhance Site via UUID
- --CPU this option can be used by itself or with any other command line option and will provide CPU percentage - this does slow the search quite a bit, so is more appropriate for searching single UUID / Directory Owner.

#### Sample Output:
```
Website ID: 98f79a38-2fc4-462b-8c99-ea111d0e3cea
Owner: northpeople
CPU Usage: 75.34%
Memory Usage: 2750 MB / 3072 MB (89.55%)
IO Usage: Read 1.85 MB/s, Write 0.92 MB/s, Total 2.77 MB/s
```

## Explanation of Metrics
- **CPU Usage (%)**: Measures the CPU time consumed relative to the allocated limit.
- **Memory Usage (MB)**: Displays the current memory consumption and total available memory for the website.
- **IO Usage (MB/s)**:
  - **Read MB/s**: Disk read speed in megabytes per second.
  - **Write MB/s**: Disk write speed in megabytes per second.
  - **Total MB/s**: Combined read and write speed.

## Notes


## License
This script is open-source and free to use under the MIT License.

