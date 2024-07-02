
FILE_SIZE=`expr 8192 "*" $KB`
READ_OP=0

TARGET_FOLDER=./device/
RESULT_FOLDER=./result/
SRC_PATH="./hypothetical/append_maker.cpp"
EXE_PATH="append_maker"

NR_SG=1
NR_DF=1023
SFS="8192K"

OPT_DIRECT=0
OPT_DEFAULT=1

DRANGE="1 2 4 8 16 32 64 128 256"
for D in $DRANGE
do

    DATA_PAT_NAME=""$DATA_NAME"p1"
    DATA_DEV="/dev/"$DATA_NAME""
    DATA_PAT="/dev/"$DATA_PAT_NAME""

    JOURNAL_PAT_NAME=""$JOURNAL_NAME"p2"
    JOURNAL_DEV="/dev/"$JOURNAL_NAME""
    JOURNAL_PAT="/dev/"$JOURNAL_PAT_NAME""

    ####trim, fdisk, mount
    source trim_NVMe.sh

    #disable meta write
    ./disablemeta.sh

    ###format mount
    printf "n\np\n1\n1\n+35G\nw\n" | sudo fdisk $DATA_DEV
    printf "n\np\n1\n2\n+2G\nw\n" | sudo fdisk $JOURNAL_DEV

    mkfs.ext4 -F -O journal_dev -b 4096 $JOURNAL_PAT
    mkfs.ext4 -F -J device=$JOURNAL_PAT -m 0 -b 4096 $DATA_PAT

    mount -o nodelalloc $DATA_PAT $TARGET_FOLDER
    echo 0 > /sys/fs/ext4/$DATA_PAT_NAME/reserved_clusters
    echo 4200000000 > /sys/fs/ext4/$DATA_PAT_NAME/mb_stream_req

    ###makefile
    APPEND_SIZE=`expr $FILE_SIZE "/" $D`
    WRITE_COUNT=`expr $FILE_SIZE "/" $APPEND_SIZE`
    DUMMYAPPEND_SIZE=`expr $FILE_SIZE "-" $APPEND_SIZE`
    TARGET_FILENAME=T$D

    g++ -D RAND_DUMMY=0 -D OPT_DIRECT=$OPT_DIRECT -D TARGET_FILENAME=\"$TARGET_FILENAME\" -D TARGET_FOLDER=\"$TARGET_FOLDER\" -D WRITE_COUNT=$WRITE_COUNT -D FILE_SIZE=$FILE_SIZE -D APPEND_SIZE=$APPEND_SIZE -D DUMMYAPPEND_SIZE=$DUMMYAPPEND_SIZE -D READ_OPTION=$READ_OP -o $EXE_PATH $SRC_PATH

    echo $APPEND_SIZE $DUMMYAPPEND_SIZE $WRITE_COUNT

    ./"$EXE_PATH"

    rm -rf $TARGET_FOLDER/D*

    filefrag $TARGET_FOLDER$TARGET_FILENAME.data

    sleep 1

    ###read test

    echo $NR_DF > /sys/block/$DATA_NAME/queue/nr_requests
    cat /sys/block/$DATA_NAME/queue/nr_requests
    echo DOF$D start | tee -a $RESULT_FOLDER"vd_$RESULT_NAME"_QD"$NR_DF".txt
    mkdir $RESULT_FOLDER"vd_$RESULT_NAME"_QD"$NR_DF"$D
    blktrace -d /dev/nvme0n1 -o $RESULT_FOLDER"vd_$RESULT_NAME"_QD"$NR_DF"$D/trace_output.blktrace -w 60
    fio --filename=${TARGET_FOLDER}T$D.data --direct=1 --rw=read --bs=$SFS --ioengine=libaio --runtime=60 --time_based --name=DF --iodepth=1023 >> $RESULT_FOLDER"vd_$RESULT_NAME"_QD"$NR_DF".txt
    blkparse $RESULT_FOLDER"vd_$RESULT_NAME"_QD"$NR_DF"$D/trace_output.blktrace -d $RESULT_FOLDER"vd_$RESULT_NAME"_QD"$NR_DF"$D/parsed_output.blkparse
    btt -i $RESULT_FOLDER"vd_$RESULT_NAME"_QD"$NR_DF"$D/parsed_output.blkparse -o $RESULT_FOLDER"vd_$RESULT_NAME"_QD"$NR_DF"$D/btt_output.txt

    echo $NR_SG > /sys/block/$DATA_NAME/queue/nr_requests
    cat /sys/block/$DATA_NAME/queue/nr_requests
    echo DOF$D start | tee -a $RESULT_FOLDER"vd_$RESULT_NAME"_QD"$NR_SG".txt
    mkdir $RESULT_FOLDER"vd_$RESULT_NAME"_QD"$NR_SG"$D
    blktrace -d /dev/nvme0n1 -o $RESULT_FOLDER"vd_$RESULT_NAME"_QD"$NR_SG"$D/trace_output.blktrace -w 60
    fio --filename=${TARGET_FOLDER}T$D.data --direct=1 --rw=read --bs=$SFS --ioengine=libaio --runtime=60 --time_based --name=SG --iodepth=1 >> $RESULT_FOLDER"vd_$RESULT_NAME"_QD"$NR_SG".txt
    blkparse $RESULT_FOLDER"vd_$RESULT_NAME"_QD"$NR_SG"$D/trace_output.blktrace -d $RESULT_FOLDER"vd_$RESULT_NAME"_QD"$NR_SG"$D/parsed_output.blkparse
    btt -i $RESULT_FOLDER"vd_$RESULT_NAME"_QD"$NR_SG"$D/parsed_output.blkparse -o $RESULT_FOLDER"vd_$RESULT_NAME"_QD"$NR_SG"$D/btt_output.txt

    #kill bg wakeup
    kill $bg_pid

    ###reset umount

    sleep 1

    umount $TARGET_FOLDER
    sleep 1
    printf "d\n1\nw\n" | sudo fdisk $DATA_DEV
    printf "d\n1\nw\n" | sudo fdisk $JOURNAL_DEV

    #enable meta write
    ./enablemeta.sh

done
