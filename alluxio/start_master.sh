#!/usr/bin/env bash

name=${1:-"master"}
hdfs_name=${2:-"namenode"}

createNetwork() {
  sudo docker network inspect alluxio #> /dev/null 2>&1

  if [ $? -eq 1 ]; then
    local network=$(sudo docker network create alluxio)
    echo "Created network --attachable alluxio $network"
  fi
}

createNetwork

id=$(sudo docker run -d --name ${name} -h ${name} --network=alluxio alluxio master start ${name})

sleep 2s

ip=$(sudo docker inspect --format '{{ .NetworkSettings.Networks.alluxio.IPAddress }}' $id)

echo Access namenode console in:
echo http://$ip:19999