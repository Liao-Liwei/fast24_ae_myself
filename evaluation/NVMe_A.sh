DATA_NAME="nvme2n1"
RESULT_NAME="NVMe-A"

KB=1024
MB=`expr 1024 "*" $KB`
STRIPE_SIZE=`expr 1024 "*" $KB`
APPEND_SIZE=`expr 32 "*" $KB`
