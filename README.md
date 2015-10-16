# Instructions for how to configure Openstack to use Brocade SDN Controller (or OpenDaylight)
# See the video of the complete install on youtube: https://www.youtube.com/watch?v=tXw4W3RQDMM
1. Create Ravello account - https://www.ravellosystems.com/
2. Copy Openstack Kilo blueprint from repo - https://www.ravellosystems.com/repo/blueprints/60360952
3. Create application
4. Add key to application
5. Add bscui port to application - http port 9001
6. Add bscrest port to application - http port 8181
7. Add novnc port to application - https port 6080
7. Publish application - chooose AWS
9. Confirm openstack works by logging into the openstack UI - use dns name and port 443 i.e. https to login to openstack UI
10. Create openstack instance to confirm that openstack is working
11. Fix novnc console access using dns name by editing /etc/nova/nova.conf on each compute node and restart nova-compute: systemctl restart openstack-nova-compute
12. Delete openstack instance
13. Install BSC on control node.  Find detailed installation video here: https://www.youtube.com/watch?v=5jxEhQXa2NM (if the installation fails this video might provide a helpful workaround: https://www.youtube.com/watch?v=n1PnXcjJHJ4)
14. Confirm UI access to BSC on control node on port 9001 but will be unable to login
15. Fix login issue by patching BSC - get patch using
   
   ``` 
   curl https://raw.githubusercontent.com/Elbrys/bsc_openstack/master/bvc2.patch > bvc2.patch 
   sudo yum install -y patch
   pushd / && patch -p0 < ~/bvc2.patch && popd
   ```

16. Confirm login to BSC now works
17. Clean openstack state
    
    ```
    . keystonerc_admin
    nova list
    nova delete <instance-name>
    neutron router-list
    neutron router-port-list <router>
    neutron router-interface-delete <router> <subnet>
    neutron floatingip-list
    neutron floatingip-delete
    neutron port-list
    neutron port-delete <port>
    neutron router-delete <router>
    neutron subnet-list
    neutron subnet-delete <subnet>
    neutron net-list
    neutron net-delete <network>
    ```

18. On control node turn off neutron server

    ```
    systemctl stop neutron-server
    ```

19. Create script set_ovs.sh, set it to executable and copy it to neutron and compute nodes

    ```
    curl https://raw.githubusercontent.com/Elbrys/bsc_openstack/master/set_ovs.sh > set_ovs.sh
    chmod a+x set_ovs.sh
    scp set_ovs.sh neutron:~/
    scp set_ovs.sh compute1:~/
    scp set_ovs.sh compute2:~/
    ```

20. On each node (neutron, compute1, compute2) turn off and disable neutron-openvswitch-agent

    ```
    systemctl stop neutron-openvswitch-agent
    systemctl disable neutron-openvswitch-agent
    ```

21. Clean openvswitch config and configure openvswitch to connect to BSC controller (neutron, compute1, and compute2 only)

    ```
    systemctl stop openvswitch
    rm -rf /var/log/openvswitch/*
    rm -rf /etc/openvswitch/conf.db
    systemctl start openvswitch
    ```

22. Confirm clean openvswitch state

    ```
    ovs-vsctl show
    ```

23. Configure manager on openvswitch using the set_ovs.sh script
    
    ```
    ./set_ovs.sh
    ```

24. Do ovs-vsctl show and notice that ovs is not connected.  Need to clear selinux permissions to allow connections.  On all 4 nodes:

    ```
    setenforce 0
    sed -i -e 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
    ```

25. Check ovs-vsctl and look for connected status - if still not connected then reboot as recommended in next step
26. Reboot compute and neutron nodes.
27. Check BSC UI topology manager to make sure that all 3 switches are showing up there.
If BSC UI topology manager isn't working ODL topology can be checked here:

   ```
   <ip or dns of controller>:8181/restconf/operational/network-topology:network-topology/
   ```

28. Configure control node to use BSC (note neutron-server is currently stopped)

    ```
    crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers opendaylight 
    crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types vxlan

    cat <<EOT>> /etc/neutron/plugins/ml2/ml2_conf.ini 
    [ml2_odl]
    password = admin
    username = admin
    url = http://192.168.0.10:8181/controller/nb/v2/neutron
    EOT

    mysql -e "drop database if exists neutron_ml2;"
    mysql -e "create database neutron_ml2 character set utf8;"
    mysql -e "grant all on neutron_ml2.* to 'neutron'@'%';"
    neutron-db-manage --config-file /usr/share/neutron/neutron-dist.conf --config-file /etc/neutron/neutron.conf \
    --config-file /etc/neutron/plugin.ini upgrade head
    ```

29. Start neutron-server

    ```
    systemctl start neutron-server
    ```
    Note that server fails to start

30. Check /var/log/neutron/server.log for issue
31. edit /etc/neutron/plugins/ml2/ml2_conf.ini to add vxlan to available network types

    ```
    vi /etc/neutron/plugins/ml2/ml2_conf.ini
    ```

32. Start neutron-server
    
    ```
    systemctl start neutron-server
    ```
    Note that server fails to start

33. Check /var/log/neutron/server.log for issue
34. Install networking-odl to fix issue with driver

    ```
    yum install -y python-pip
    pip install networking-odl
    ```

35. Start neutron-server - this time it should start

    ```
    systemctl start neutron-server 
    ```

36. Create instances in openstack UI and verify you can ping between instances
37. You can check ODL neutron ml2 config here:
    
    http://<dns or ip of server>:8181/controller/nb/v2/neutron/networks

39. Check output of ovs-vsctl on compute and neutron nodes to see correct config.  It should look similar to this (note the vxlan tunnels under the br-int port):

```
[root@compute1 ~]# ovs-vsctl show
44ca1d09-dd9c-4b2b-b51e-0629a5924c86
    Manager "tcp:192.168.0.10:6640"
        is_connected: true
    Bridge br-int
        Controller "tcp:192.168.0.10:6653"
            is_connected: true
        fail_mode: secure
        Port br-int
            Interface br-int
                type: internal
        Port "vxlan-192.168.0.11"
            Interface "vxlan-192.168.0.11"
                type: vxlan
                options: {key=flow, local_ip="192.168.0.12", remote_ip="192.168.0.11"}
        Port "vxlan-192.168.0.13"
            Interface "vxlan-192.168.0.13"
                type: vxlan
                options: {key=flow, local_ip="192.168.0.12", remote_ip="192.168.0.13"}
        Port "tape0a7a301-8b"
            Interface "tape0a7a301-8b"
    Bridge br-ex
        Port br-ex
            Interface br-ex
                type: internal
    Bridge "br-eth1"
        Port "br-eth1"
            Interface "br-eth1"
                type: internal
        Port "eth1"
            Interface "eth1"
    ovs_version: "2.3.1"
```
