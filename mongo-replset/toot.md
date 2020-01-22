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

> [Note] All tutorial actions will take place from inside this folder.

## Running a mongo instance in docker
To create a non persistent mongo node we can simply start a standard container:
```docker run -d --rm --name mongo-toot mongo```
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

Once you have this IP address you can access it using the mongo shell. If you have a local mongo installation, you can use that, or you can use another mongo container!
```
                           Name      Image Cmd   Args
docker run -it --rm --name mongo-cli mongo mongo --host <mongo container IP>
```
The default container opens port 27017 by default so it is accessible as any other mongo instance.

> [Note] To stop your containers between steps use `docker kill mongo-toot`. As we are using the `--rm` flag the container will be completely deleted when it exits.

## Persistence

Try inserting a document into your database.
```
docker run -it --rm --name mongo-cli mongo mongo test --eval "db.test.insert({hey: 'there'})" --host 172.17.0.2
```
And now make sure it's there with:
```
docker run -it --rm --name mongo-cli mongo mongo test --eval "db.test.find()" --host 172.17.0.2
```
Now exit the mongo-cli container and `docker kill` the mongo-toot container.
Restarting and reconnecting to the new container will now present you with an uninitiated replicaset. The database you just created is also missing. This is because, by default, the data is stored inside the container on a volatile filesystem.
To make it stick, we need to mount a volume from our local file system to use as persistent storage. Make sure to use the absolute path for the volume so that you dont accidentally mount the wrong thing. Mount the volume using the command:
```
docker run -d --rm -v $PWD/data1:/data/db -v $PWD/mongod.conf:/etc/mongod.conf --name mongo-toot mongo
```
Now try to insert a document, kill the container, and then see if it still exists the next time you turn it on. It should be there! You now have a persitent volume that can safely contain a copy of your database. You could now extend this to be a highly available and reliable unit of storage, but that is well beyond the scope of this tutorial.

## Passing configuration
Default mongo configuration comes from a config file installed on the disk during installation. This can be found in `/etc/mongod.conf`. By default replicasets are not enabled, nor is authentication. To edit this in a containerised system you will need to mount a local copy of the config file in and tell mongo where to load it from.

To mount a local file into a container we use the `-v local:remote` argument. For this example we will use `mongod.conf`. Docker doesn't seem to like it if you use shell expansions for file paths so we shall use command substitution instead. 
```-v $(pwd)/mongod.conf:/etc/mongod.conf```
This will mount the file in the current directory into the container as `/etc/mongod.conf`
You might think that just mounting this file would make mongod use it for configuration but, confusingly, you'd be wrong. For some reason container mongo does not seem to match RPM mongo in this regard, so instead we need to point it in the right direction. This is done through the use of a parameter that we shal pass into the container at startup. The complete startup string with the mount point and parameter is as follows:

```docker run -d --rm -v $(pwd)/mongod.conf:/etc/mongod.conf --name mongo-toot mongo --config/etc/mongod.conf```
 
How exciting! It does exactly the same thing as before, but now it does it because you told it to.
The next step is to enable replication.
Edit `./mongod.conf` by uncommenting the two lines:
``` 
replication:
      replSetName: my_little_repl
```
Restart the container now and you'll see... no difference! Replication is not initialised by default, but you are only able to initialise it once the setting has been supplied.
If you run `rs.status()` now you will get a response somewhat like:

``` 
rs.status()
{
	"operationTime" : Timestamp(0, 0),
	"ok" : 0,
	"errmsg" : "no replset config has been received",
	"code" : 94,
	"codeName" : "NotYetInitialized",
	...
}
```

To activate the replicaset you can run the command: `rs.initiate()`. This will change the visible mongo prompt to show a secondary status.
Hit enter again after a few seconds and the prompt will change to primary. As there is only one node in this cluster, it takes a moment to elect a primary, and it will be in the secondary state until that happens.

## Making a real cluster

Now we have configured one node successfully, we need to add some more nodes to make it a real cluster. This is the point at which we need to handle the communication between the nodes. 
Options:
1. Host Networking - When you run a container you can connect it to the network of the host. This means it will share the port usage of localhost. To use this option, all instances will have to have different configurations so that they can all run on different ports. This is messy and cumbersome. 
2. A tidier way is to use a docker network. When running in a docker network, all containers can talk to all other containers using their hostnames, which equate to the names of the containers. All containers will be given separate IP addresses within that network so all nodes can still run on the same port.

### Creating a network
We're going for option #2. Creating a network is very simple. The command to create a network called mongo is:
```
docker network create mongo
```
Connecting a container to this network is now as simple as providing the `--network <name>` argument when you create it.

You can check your docker networks with the command:
```
docker network list
```

### Preparing the cluster

The only requirement to get multiple nodes into a replicaset is that the nodes are all configured with the same `replSetName`. As we can use the same config for all nodes, this is easy to achieve.

> [Note] Before you start, make sure to deleteyour persistent any persistent data folders you have used, i.e `./data1`, to get rid of all traces of previous databases.

For this example we are going to create three separate nodes and then connect them all together. As an aid for starting multiple containers, I have provided a small script in `run.sh`:
```
docker run -d --rm --network mongo -v $PWD/data1:/data/db -v $PWD/mongod.conf:/etc/mongod.conf --name mongo-toot-1 mongo --config /etc/mongod.conf
docker run -d --rm --network mongo -v $PWD/data2:/data/db -v $PWD/mongod.conf:/etc/mongod.conf --name mongo-toot-2 mongo --config /etc/mongod.conf
docker run -d --rm --network mongo -v $PWD/data3:/data/db -v $PWD/mongod.conf:/etc/mongod.conf --name mongo-toot-3 mongo --config /etc/mongod.conf
```

> [Note] In addition to the helper for starting 3 containers, there is also `./kill.sh` to kill all the containers as necessary.

All three containers will be created with the ability to:
* Talk to each other via hostname
* Persist data to local folder
* Be part of the same replica set

### Building the cluster

The only step we now need to perform is to initiate the replica set and add the nodes.
You can use the `./mongo.sh` script with an numeric argument to connect to a node of your choice, i.e `./mongo.sh 1` to connect a mongo shell to mongo-toot-1. 
* Pick a node that you want to be the primary and connect to it. The guide will assume you chose mongo-toot-1
* Run the initiation command: `rs.initiate()`. 
* Add the other nodes. 
  - `rs.add("mongo-toot-2:27017")`
  - `rs.add("mongo-toot-3:27017")`
Actually, we changed our mind and the 3rd node only needs to be an arbiter!
* Remove the node
  - `rs.remove("mongo-toot-3:27017")`
  - `rs.addArb("mongo-toot-3:27017")`
* Gaze in wonder at your glorious mongo cluster
  - `rs.status()` - Check all your nodes are present and connected

### Reconfiguring
You may have noticed that when we intiated the replica set on mongo-toot-1 it added the node with container hash as its ID. This is inconsistent so let's change it. 
One thing to remember when using the mongo interface is that it has a full javascript interpreter running that you can use to help you out.
* Get the current configuration
  - `const conf = rs.conf()`
* Edit the name of the first member
  - `conf.members[0].host = "mongo-toot-1"`
* Apply the altered configuration
  - `rs.reconfig(conf)`
* Check that your changes have been applied
  - `rs.status()`
The first member should now have the correct name.

### Changing the primary node
Sometimes you want to stop a node from being primary. To do this you simply tell that node to step down with the command `rs.stepDown()`. Another node will be elected as primary.

### Reconfiguring when you have no primary available
Imagine you have a 3 node cluster. Your data is up to date on all nodes. But two of them have gone down and you need to preserve the data before you go any further. While you still have access to the third node, you will struggle to perform any actions as that node is stuck in a secondary state with no one else to vote for it. In fact, let's not imagine, lets reproduce it. `docker kill mongo-toot-2 mongo-toot-3` and you will be left with one working node. 

To get it back to a usable state we need to remove the other nodes so that it can have a majority in the cluster. Attempting to `rs.remove(...)` or `rs.add(...)` will result in an error message. However, like Luke, we can use the force. Try the following:
* Get the current configuration
  * `const conf = rs.conf()`
* Remove the other two members from the member array
  * `conf.members = [conf.members[0]]`
* Reconfigure, using the force
  * `rs.reconfig(conf, {force: true})`
You will now be back to a single node replica set that can elect itself as primary, giving you full use of the database

> [Note] Even if the node is in the secondary state, you can always exec into the container and perform a mongodump on the data. So taking backups is always an option, you just need to make sure that the data you are backing up is up to date.


