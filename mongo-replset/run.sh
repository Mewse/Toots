docker run -d --rm --network mongo -v $PWD/data1:/data/db -v $PWD/mongod.conf:/etc/mongod.conf --name mongo-toot-1 mongo --config /etc/mongod.conf
docker run -d --rm --network mongo -v $PWD/data2:/data/db -v $PWD/mongod.conf:/etc/mongod.conf --name mongo-toot-2 mongo --config /etc/mongod.conf
docker run -d --rm --network mongo -v $PWD/data3:/data/db -v $PWD/mongod.conf:/etc/mongod.conf --name mongo-toot-3 mongo --config /etc/mongod.conf

