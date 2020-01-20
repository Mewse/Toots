# MongoDB ReplicaSets

## What the toot?
Manually configuring and initialising a MongoDB replicaset. 

## What should you know?
* Basic docker usage

## What will you learn?
- Some more advanced docker features
- ReplicaSet configuration
- Manually adding/removing nodes/arbiters
- Resetting nodes
- Forcing reconfiguration

# The Toot.
## Setup
* Checkout the toot repo from https://github.com/Mewse/Toots.git
* cd into mongo-replset

[Note] All tutorial actions will take place from inside this folder.

## Running a mongo instance in docker
To create a non persistent mongo node we can simply start a standard container:
```docker run -itd --rm --name mongo-toot mongo```
This will start a mongo instance running with a default mongo configuration on port 27017 inside a container called mongo-toot.
To connect to this we need to know the ip address of the container. To find this you can either inspect the container: ```docker inspect mongo-toot``` or you can check the contents of `/etc/hosts` inside the container with: ```docker exec mongo-toots /bin/bash -c 'cat /etc/hosts'```

This should give you an output similar to the following: 
```
127.0.0.1       localhost
::1     localhost ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
172.17.0.4      f012407b78be
```

Docker inserts a hostname entry mapping 172.17.0.# to the abbreviated container ID.

[Note] The following test requires a local install of mongo
Once you have this IP address you can access it using the mongo shell
```mongo --host <mongo container IP>```
The default container opens port 27017 by default so it is accessible as any other mongo instance.

[Note] To stop your containers between steps use `docker kill mongo-toot`. As we are using the `--rm` flag the container will be completely deleted when it exits.

## Passing configuration
Default mongo configuration comes from a config file installed on the disk during installation. This can be found in `/etc/mongod.conf`. By default replicasets are not enabled, nor is authentication. To edit this in a containerised system you will need to mount a local copy of the config file in and tell mongo where to load it from.

To mount a local file into a container we use the `-v local:remote` argument. There are two provided config files, for this example we will use `mongod-standalone.conf`. Docker doesn't seem to like it if you use shell expansions for file paths so we shall use command substitution instead. 
```-v $(pwd)/mongod-standalone.conf:/etc/mongod.conf```
This will mount the file in the current directory into the container as `/etc/mongod.conf`
You might think that just mounting this file would make mongod use it for configuration but, confusingly, you'd be wrong. For some reason container mongo does not seem to match RPM mongo in this regard, so instead we need to point it in the right direction. This is done through the use of a parameter that we shal pass into the container at startup. The complete startup string with the mount point and parameter is as follows:
```docker run -itd --rm -v $(pwd)/mongod-standalone.conf:/etc/mongod.conf --name mongo mongo --config/etc/mongod.conf```
 

