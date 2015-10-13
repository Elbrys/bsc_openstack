#/bin/bash
# (C)2015 Brocade Communications Systems, Inc.
# 130 Holger Way, San Jose, CA 95134.
# All rights reserved.
#
# Brocade, the B-wing symbol, Brocade Assurance, ADX, AnyIO, DCX, Fabric OS,
# FastIron, HyperEdge, ICX, MLX, MyBrocade, NetIron, OpenScript, VCS, VDX, and
# Vyatta are registered trademarks, and The Effortless Network and the On-Demand
# Data Center are trademarks of Brocade Communications Systems, Inc., in the
# United States and in other countries. Other brands and product names mentioned
# may be trademarks of others.
#
# Use of the software files and documentation is subject to license terms.
ethif=$(ip -o addr show dev br-eth1 | grep -w inet | awk '{print $4}' | sed -e 's/\/.*//g')
read ovstbl <<< $(ovs-vsctl get Open_vSwitch . _uuid)
ovs-vsctl set Open_vSwitch $ovstbl other_config:local_ip=$ethif
ovs-vsctl set-manager tcp:192.168.0.10:6640