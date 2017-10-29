#!/bin/bash
################################
DBs=()
RAM_useds=()
Modes=()
Keys=()
Threads=()
Workloads=()
################################

benchmark_file='@BUILD/src/ioarena'
ram_user_file='ram_user.py'
disk='/dev/nvme0n1'
mount_point='/mnt/MDBX'
filled_dbs='/mnt/MD1/Filled_DBs'

#DBs+=( rocksdb )
#DBs+=( sophia )
DBs+=( mdbx )
#DBs+=( wiredtiger )

RAM_useds+=( 106 )
#RAM_useds+=( 10 )

#Modes+=( sync )
Modes+=( lazy )
#Modes+=( nosync )

#Keys+=( 1000 )
#Keys+=( 1000000 )
Keys+=( 1000000000 )
#Keys+=( 17000000000 )
#Keys+=( $((17000000000/128)) )

key_size=8
val_size=16
#val_size=$((16*128))

Threads+=( 32 )
Threads+=( 256 )

Workloads+=( get )
Workloads+=( mix_70_30 )
Workloads+=( mix_50_50 )
Workloads+=( mix_30_70 )

test_operations=100  # Coefficient
#test_operations=1000

format_disk=0


test_res_dir='Tests'

pattern='/*/'


if [[ ! -f $benchmark_file ]] ; then
    echo "Benchmark executable $benchmark_file does not exist, aborting."
    exit
fi


mkdir -p $test_res_dir

cur_time=$(date +"%F_%H-%M-%S")


#set -x

umount ${mount_point}

for RAM_used in ${RAM_useds[@]}; do

    echo "Allocating ${RAM_used}GB RAM"
    python ${ram_user_file} start ${RAM_used}
    sleep $((RAM_used/2))

    for DB in ${DBs[@]}; do
        for mode in ${Modes[@]}; do
            for keys_num in ${Keys[@]}; do

                if [ $format_disk == 1 ]; then
                    echo "Cleaning disk..."
                    yes | mkfs.ext4 ${disk}
                fi

                mount ${disk} ${mount_point}

                db_dir=${mount_point}/${DB}_${keys_num}
                mkdir -p ${db_dir}

                ${benchmark_file} -D ${DB} -B set -m ${mode} -p ${db_dir} -k ${key_size} -v ${val_size} -n ${keys_num} -a ${keys_num} -C ${test_res_dir}/${DB}_${RAM_used}_${mode}_${keys_num}_${key_size}_${val_size}_set_${cur_time}.csv > ${test_res_dir}/${DB}_${RAM_used}_${mode}_${keys_num}_${key_size}_${val_size}_set_${cur_time}
                echo "${test_res_dir}/${DB}_${RAM_used}_${mode}_${keys_num}_${key_size}_${val_size}_set DONE!"

                cp -rf ${db_dir} ${filled_dbs}/${DB}_${keys_num}_${key_size}_${val_size}_${cur_time}
                echo "Filled DB (${DB}) with ${keys_num} keys has been copied to ${filled_dbs}"

                umount ${mount_point}

	        for thread_num in ${Threads[@]}; do

                    num_op=`echo "e(l(${keys_num})/6)*${test_operations}/${thread_num}*100*168*6" | bc -l | cut -f1 -d.`
                    echo "Now starting tests with ${thread_num} threads, ${num_op} operations per thread. Total "$((${num_op}*${thread_num}))" operations"

                    for workload in ${Workloads[@]}; do

                        mount ${disk} ${mount_point}

                        ${benchmark_file} -D ${DB} -B ${workload} -m ${mode} -p ${db_dir} -k ${key_size} -v ${val_size} -n ${num_op} -a ${keys_num} -r ${thread_num} -C ${test_res_dir}/${DB}_${RAM_used}_${mode}_${keys_num}_${key_size}_${val_size}_${workload}_${thread_num}_${cur_time}.csv > ${test_res_dir}/${DB}_${RAM_used}_${mode}_${keys_num}_${key_size}_${val_size}_${workload}_${thread_num}_${cur_time}
                        echo "${test_res_dir}/${DB}_${RAM_used}_${mode}_${keys_num}_${key_size}_${val_size}_${workload}_${thread_num} DONE!"

                        umount ${mount_point}

                    done
                done
            done
        done
    done

    echo "Freeing allocated RAM"
    python ${ram_user_file} stop

done
