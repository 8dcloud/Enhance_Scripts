# Website Resource Usage Monitoring Script for EnhanceCP

## Overview
**Thank you to WebGeeSolutions for intitial script - You rock!!!**
This Bash script retrieves real-time CPU, Memory, and I/O usage for a specific website running in a cgroup-based hosting environment. It provides live statistics, including:
- **CPU Usage (%)**
- **Memory Usage (MB and Percentage)**
- **I/O Read, Write, and Total Speed (MB/s)**

## Prerequisites
- The system must support **cgroups v2**.
- The cgroup path should be **`/sys/fs/cgroup/websites/<website_id>`**.
- The script must be executed with appropriate permissions to read cgroup files.

## Installation
1. Copy the script to a directory on your server.
2. Give it a name such as website-usage.sh
3. Give it execution permissions:
   ```bash
   chmod +x website-usage.sh
   ```
## Usage
- Run the script and it will request one/several or all sites.
- When asked, if you choose one/several the script will then prompt for UUID **or** Directory owner. You should use at least 4-5 characters
- If you choose one/several, and user, all users that match the string you enter will be output (i.e. "north" would provide all users starting with 'north')

### Example:
```bash
./website-usage.sh
```
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

