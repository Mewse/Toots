docker run -it -d --rm --network mongo -v $PWD/data1:/data/db -v $PWD/mongod.conf:/etc/mongod.conf --name mongo1 mongo --config /etc/mongod.conf
docker run -it -d --rm --network mongo -v $PWD/data2:/data/db -v $PWD/mongod.conf:/etc/mongod.conf --name mongo2 mongo --config /etc/mongod.conf
docker run -it -d --rm --network mongo -v $PWD/data3:/data/db -v $PWD/mongod.conf:/etc/mongod.conf --name mongo3 mongo --config /etc/mongod.conf

