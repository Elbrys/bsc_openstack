# How to integrate the Brocade SDN Controller or Opendaylight with Openstack using Ravello

This blog is based on the video I created (https://www.youtube.com/watch?v=tXw4W3RQDMM) and the corresponding instructions (https://github.com/Elbrys/bsc_openstack).  So feel free to refer to those if you want more details.

So why write this blog?  There are some existing instructions out there for integrating OpenDaylight or the Brocade SDN Controller with OpenStack. 
For example here's a few links that I found useful when putting together this blog:

* https://wiki.opendaylight.org/view/OpenStack_and_OpenDaylight
* https://www.rdoproject.org/networking/helium-opendaylight-juno-openstack/
* http://www.brocade.com/content/html/en/configuration-guide/SDN-Controller-2.0.1-OpenStack-Integration/index.html
 
However, I didn't want to go through all the work of installing OpenStack on real hardware.  Especially since to take advantage of the 
 neutron OpenDaylight networking integration I wanted to have several nodes which ruled out just installing devstack on 
 my laptop.  That had me wondering if there was a way to run OpenStack on AWS and some google searches led me to this blog: 
 
* https://www.ravellosystems.com/blog/openstack-packstack-installation-on-aws/

The best part was that I could use an existing blueprint so not only would I not have to install openstack on a bunch of
real hardware, but I could also quickly get it bootstrapped from a blueprint in AWS.  In choosing Ravello I had to tweak
the instructions in the links above so that all the pieces worked in the Ravello environment i.e. basically they needed to
work behind a NAT firewall.  And so here are those instructions:

* Create a Ravello account here: https://www.ravellosystems.com/ You get 2 weeks free and after that you have to pay for 
what you use.
* Once you have an account add this Kilo blueprint into your account library: https://www.ravellosystems.com/repo/blueprints/60360952

  ![screenshot 1]
  (img/screen_shot_1.png)

* Create an application from the blueprint. Your application should look something like this:
  
  ![screenshot 2]
  (img/screen_shot_2.png)
  
* Now you need to configure your application correctly before publishing it.  Important! the key can only be set before 
the application is published so make sure you don't forget to set it before publishing the app:
    * Add a key to the application.  You can either have Ravello generate a keypair for you (you will need to save the private key) or upload an existing public key.
    * Add 3 services and their associated ports.  Go to the "services" tab and add the following ports:
        * http port 9001 for the Brocade SDN Controller UI
        * http port 8181 for the Brocade SDN Controller REST API
        * https port 6080 for the OpenStack NOVNC console

  ![screenshot 3]
  (img/screen_shot_3.png)

* After you have configured your application you can publish it which automatically starts it too.  I recommend publishing 
it to AWS as I found that the performance of the google nodes was unpredictable and that could cause problems with the BSC install.
Note that publishing and starting the application takes several minutes (for me it took about 8 minutes).  
* Now you can confirm that OpenStack is working correctly by logging into the OpenStack instance you just started in AWS.  Once the nodes
have started in the Ravello UI you can see the DNS name that was assigned to each VM in your application in the Canvass tab.
 You will want to try logging into the OpenStack UI service using this DNS name which is on port 443 of the Controller VM.
  
  ![screenshot 4]
  (img/screen_shot_4.png)
  
  Since this is port 443 and https you will most likely get a certificate error because of the self signed certificate in use by this
  install of OpenStack.  You will need to override this error depending on the browser you are using.  Once you have overriden this
  error you can login to the OpenStack UI. The credentials are "admin" and the password is "ravellosystems".  Once you have logged in to
  OpenStack you can play around with creating VMs etc.  You will notice, however, that the console does not work for the VMs.  In order
  to get the console working you will need to go in and make some changes to the OpenStack configuration to accomodate this Ravello setup as follows:
 
  You will need to use the DNS name of the controller node to ssh into the OpenStack controller.  To ssh into the controller you will 
  need to configure your ssh client to use the private key that you installed above before publishing your application.  Your ssh command
  might look something like this: "ssh -i ~/.ssh/id_rsa centos@controller-bscwithopenstackki-o1wdnkwc.srv.ravcloud.com" Note: ssh  on the nodes is 
  specifically configured to disallow username / password login.  The only way you can login is using your private key.  You ssh into the
  controller node as the centos user.  So you need to switch to the root user as follows: "sudo su - root".  Once you are the root user
  you can ssh into the other OpenStack nodes by typing any of the following: "ssh compute1" or "ssh compute2" or "ssh neutron".
  To fix the novnc console issue you will need to go to both of the compute nodes via ssh and edit the /etc/nova/nova.conf file and 
  replace the 192.x.x.x address for the novncproxy_base_url setting with the DNS name of the controller node and restart the nova compute
  service.  You restart the nova compute service as follows: "systemctl restart openstack-nova-compute".  Once you have done that 
  on both compute nodes you can go back and try the novnc console in the OpenStack UI again.  Note: since the novnc console uses https
  and port 6080 you may have to override the self signed certificate again for this port.  
  
* Once you have OpenStack working correctly in Ravello, you can now proceed to installing the BSC controller.  Follow the instructions
included with the Brocade Controller and/or watch the Jim Burns video (link below) to install the controller on the OpenStack control node.  You could
create a whole other node specifically for the BSC controller, however, for simplicity I decided to reuse the control node.  Copy the 
BSC install gz file on the controller using scp (again you will use the private key you installed before publishing the app).  Then you can
proceed with the install.  Jim Burns created an excellent video detailing the install process so feel free to check that out if you 
have any questions: https://www.youtube.com/watch?v=5jxEhQXa2NM.  The key thing you must do during the install is say yes to installing the
ovsdb feature as this is required to make the OpenStack integration work.  You can choose to install or not install the other features as
I don't think they will impact the OpenStack integration.
  
* Once the BSC controller is installed, you can use the Ravello services window to login to the BSC UI or just go to the controller DNS name
and port 9001.  The default username and password to login are "admin" and "admin".  However, you will notice that you cannot login to the
UI.  This is because you need to patch the Brocade install in order to be able to login in to the UI from behind a NAT firewall.  To patch
it you will need to ssh into the control node and type the following: 
   
    ```
    curl https://raw.githubusercontent.com/Elbrys/bsc_openstack/master/bvc2.patch > bvc2.patch
    sudo yum install -y patch
    pushd / && patch -p0 < ~/bvc2.patch && popd
    ```
Now you should be able to login to the Brocade UI.

* Now you are ready to make the configuration changes to OpenStack to make it work with the Brocade SDN Controller.  First you will
need to clear its existing state i.e. delete all vms, networks, etc that have been created under neutron.  You can do this either through
the UI or through the cli.  Note, to use the cli you will need to ssh into the controller and "sudo su - root" to switch to the root user.  Also
you will need to setup the admin credentials.  To do this execute the keystonerc_admin script in the root home directory as follows: ". keystonrc_admin".
Then use the following commands to list and delete all the elements:

  ```
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
* When you have cleaned up the neutron OpenStack state, you will need to stop the neutron server. On the control node as root type: "systemctl stop neutron-server"

* You will then want to create a little script for yourself to setup the openvswitch (ovs) instances correctly on each of the nodes.  I recommend grabbing
the script from my repository and copying it onto each node:

  ```
  curl https://raw.githubusercontent.com/Elbrys/bsc_openstack/master/set_ovs.sh > set_ovs.sh
  chmod a+x set_ovs.sh
  scp set_ovs.sh neutron:~/
  scp set_ovs.sh compute1:~/
  scp set_ovs.sh compute2:~/
  ```

* Then you need to go and disable the neutron openvswitch agent on the compute and neutron nodes.  To do that ssh into each node (compute1, compute2, neutron)
and type the following:

  ```
  systemctl stop neutron-openvswitch-agent
  systemctl disable neutron-openvswitch-agent
  ```

* Next you need to cleanup up any existing openvswitch configuration.  To do that do the following on the compute and neutron nodes.  Note: At any point you can type "ovs-vsctl show" to see the openvswitch configuration:

  ```
  systemctl stop openvswitch
  rm -rf /var/log/openvswitch/*
  rm -rf /etc/openvswitch/conf.db
  systemctl start openvswitch
  ```

* Use the set_ovs.sh script to configure openvswitch to use the Brocade controller.  Invoke it as follows: "./set_ovs.sh". You will also need to 
change the selinux configuration to allow the openvswitch instance to communicate with the controller.  Since this is a demo I just disabled selinux as 
follows (first line disables it now, second line keeps it disabled after restart):

  ```
  setenforce 0
  sed -i -e 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
  ```
  
  Note! you will need to make the selinux change to the control node too.
  After these changes to openvswitch in my experience you will need to reboot the node (compute1, compute2, neutron) in order for ovs and the network stack to start working correctly together.  

  After the node reboots you should see that ovs-vsctl shows a connection to the Brocade controller something like the following:

  ```
  [root@compute1 ~]# ovs-vsctl show
  44ca1d09-dd9c-4b2b-b51e-0629a5924c86
      Manager "tcp:192.168.0.10:6640"
          is_connected: true
  ```

  You can also go to the Brocade Controller UI and the topology manager and check to make sure the OVS instances show up there.

![screenshot 5]
(img/screen_shot_5.png)

* Once you have configured the nodes (compute1, compute2, and neutron) correctly and they appear in the Brocade UI, you need 
to configure the neutron server to use the Brocade SDN controller.  On the controller node type the following as root:

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

  Now before you start the neutron server you need to fix a couple more things:

  First edit the /etc/neutron/plugins/ml2/ml2_conf.ini file and add vxlan to the available network types

  Next, you need to install networking-odl.  I'm not sure why the ODL instructions and Brocade instructions don't mention 
this (maybe it is already included in devstack but not pacstack?) but 
it took me a while to figure out that it was missing so hopefully I can save you some pain debugging this.  To install networking-odl do 
the following:

  ```
  yum install -y python-pip
  pip install networking-odl
  ```

* Now you are ready to start the neutron server and it should start correctly.  To start it type: "systemctl start neutron-server".  If you have 
any issues starting it look in the logfile /var/log/neutron/server.log to find the exact issue. 
 
That's it.  You should now have a working copy of OpenStack with networking controlled by the Brocade SDN Controller.  Note that the Brocade SDN Controller
does not install as a service and does not start automatically so if you stop it or reboot the control node you will need to go in and manually start it.  Or
you can configure it to automatically start at boot but I am not going to detail how to do that here.  You could also play around with using docker to run the Brocade Controller and have that automatically start if you want.  Take a look at 
https://github.com/Elbrys/bvc_docker if you are interested in running the Brocade Controller inside a docker container.  If you have any issues, take a look at the video (https://www.youtube.com/watch?v=tXw4W3RQDMM)
which is a video of me doing all of this from beginning to end.  If you have any questions this may answer them for you.  If you still have questions, feel free to email me: arooney@elbrys.com
