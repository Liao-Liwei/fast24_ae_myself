#trim
echo "trim command"
nvme format $DATA_DEV --ses=1 --pi=0 --namespace-id=1

sync; echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null
sleep 5
