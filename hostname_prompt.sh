#!/bin/bash

# Ask the user for the hostname
read -p "Please enter the hostname: " HOSTNAME

# Save the hostname to a file that the preseed can read
echo "d-i netcfg/get_hostname string $HOSTNAME" > /var/tmp/hostname_answer.cfg

# Include the answer file in the preseed
echo "d-i preseed/include_command string cp /var/tmp/hostname_answer.cfg /tmp/preseed.cfg" >> /tmp/preseed.cfg
