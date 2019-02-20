#!/bin/bash

netA="
192.168.17.1
192.168.17.2
192.168.17.3
192.168.17.5
192.168.17.6
"

netB="
192.168.20.1
192.168.20.2
192.168.20.3
192.168.20.5
192.168.20.6
"

dir="AtB"

sshCon="$netA"
toChange="$netB"

function sshChk(){
    toChk=$1
    for cli in $toChk;do
	ssh $cli ls
	ret=$?
	if [ $ret -ne 0 ];then
	    echo "sshChk error for $cli,exit"
	    exit
	fi
    done
}


function doChange(){
    toCon=$1
    toChange=$2

    for cli in $sshCon;do
	ssh $cli systemctl restart NetworkManager

    done
}

function main(){
    sshChk "$netA"
    sshChk "$netB"
}

main
