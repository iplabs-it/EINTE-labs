#!/bin/bash
# Live packet capture using tcpdump piped to Wireshark
# Usage: bash capture.sh <container-namespace> <interface>
# Example: bash capture.sh clab-ospf-R1 eth1
sudo ip netns exec $1 tcpdump -U -nni $2 -w - | wireshark -k -i -
