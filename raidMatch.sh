#!/bin/bash

raidCmd="./storcli64"
raidPhyDrvInfos=""

function depChk(){
    if ! [ -x $raidCmd ];then
	echo "raidCmd $raidCmd not executable,exit -1"
	exit -1
    fi

    cmd=smartctl
    pkg=smartmontools

    command -v $cmd >/dev/null 2>&1
    if ! [ $? ];then
        echo "cmd $cmd not found,do yum install $pkg"
        yum --assumeyes install  $pkg
    fi
}

function queryControl(){
    idtLines=`$raidCmd show|awk '/-----------------------/ {printf NR" "} END { print ""}'`
    start=`echo "$idtLines" | awk '{ print $2}'`
    end=`echo "$idtLines" | awk '{ print $3}'`

    ((num=end-start-1))
    echo "$num"
}

function phyDrvInfo(){
    ctrlId=$1

    drvs=`$raidCmd /c$ctrlId show | awk '/^[[:digit:]]+:[[:digit:]]+/ { print $1}'`
    for drv in $drvs;do
	eid=${drv/%:*}
	sid=${drv/#*:}

	infos=`$raidCmd /c$ctrlId/e$eid/s$sid show all`
	wwn=`echo "$infos" | grep WWN | awk '{print $3}'`
	sn=`echo "$infos" | grep SN  | awk '{print $3}'`

	type=`echo "$infos" | awk '/^[[:digit:]]+:[[:digit:]]+/ { print $8}'`
	#echo -e "type-ctrlId-eid:sid-sn: $type \t$ctrlId \t$drv \t$sn"

	raidPhyDrvInfos="$sn,$ctrlId,$drv,$type $raidPhyDrvInfos"
    done
}

function sysBlocksSN(){
    blocks=`lsblk | grep disk | sort | awk '{print $1}'`
    for blk in $blocks;do
	sn=`smartctl -i /dev/$blk | grep -i '^Serial number:' | awk '{print $3}'`
	phyInfo=`matchblock $sn`
	printf "sysblk-sn: %-5s\t" $blk
	echo -e "${phyInfo//,/\t}"
    done
}

function matchblock(){
    sysblocksn=$1
    if [ X$sysblocksn == X ];then
	echo "sysblocksn empty,return" > 2
	return
    fi

    for phyInfo in $raidPhyDrvInfos;do
	phySN=`echo $phyInfo | awk -F "," '{print $1}'`
	if [ X$sysblocksn == X$phySN ];then
	    echo "$phyInfo"
	    break;
	fi
    done
}

function main() {
    raidPhyDrvInfos=""
    nums=`queryControl`
    for (( i = 0; i < $nums; i++ )); do
	phyDrvInfo $i
    done

    sysBlocksSN
}

main
