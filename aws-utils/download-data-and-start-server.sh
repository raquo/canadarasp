#!/bin/bash
MODEL=${1:-"gdps"}
echo Downloading data for $MODEL
cd /home/ubuntu/canadarasp/aws-utils
source create-download-box.sh /mnt
cd /home/ubuntu/canadarasp/continental-test
source guess-time.sh $MODEL
./download-data.sh $MODEL
cd /home/ubuntu/canadarasp/aws-utils
source unmount-download-box.sh
source start-compute-server.sh
( sleep 7200 ; source stop-compute-server.sh )
