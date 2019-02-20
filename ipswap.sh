#!/bin/bash

netA="
192.168.17.1
192.168.17.2
192.168.17.3
192.168.17.4
192.168.17.5
192.168.17.6
"
netA="
192.168.17.1
""

netB="
192.168.20.1
192.168.20.2
192.168.20.3
192.168.20.4
192.168.20.5
192.168.20.6
"
netB="
192.168.20.1
""

netMA="
192.168.17.x
"
netMB="
192.168.120.
"
function sshChk(){
    toChk=$1
    for cli in $toChk;do
	ssh $cli 'ls 2>&1 >/dev/null'
	ret=$?
	if [ $ret -ne 0 ];then
	    echo "sshChk error for $cli,exit"
	    exit
	fi
    done
}


function doChange(){
    toCons=$1
    toChanges=$2
    netM=$netMB

    i=0
    for cli in $toCons;do
	((i+=1))
	toCh=$(echo $toChanges | awk "{print \$$i}")
	sfix=${toCh##*.}

	ssh $cli systemctl restart NetworkManager

	inf=`ssh $cli 'ip a' | grep "$toCh" | awk '{print $8}'`
	link=`ssh $cli 'nmcli' | grep ": connected to " | grep "$inf" | sed 's/: connect.*//'`

	mdgw=`ssh $cli 'ip r' | grep default | grep -c $link`
	if [ $mdgw -ge 1 ];then
	    ipgw=`ssh $cli 'ip r' | grep default | awk '{print $3}'`
	    gwSfix=${ipgw##*.}
	fi

	echo "$cli: $toCh->$netM,$inf,$link,$mdgw"

	#do modify
	if [ X$debug == X ];then
	    ssh $cli "nmcli connection modify $link ipv4.address $netM.$sfix/24"
	    if [ $mdgw -ge 1 ];then
		ssh $cli "nmcli connection modify $link ipv4.gateway $netM.$gwSfix"
	    fi
	    ssh $cli "nmcli connection down $link;nmcli connnection up $link"
	fi

    done
}

function main(){
    sshChk "$netA"
    sshChk "$netB"
}

debug="yes"
main
