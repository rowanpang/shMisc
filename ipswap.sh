#!/bin/bash

nodeNum=6 			#nodeNum
sfxStart=1 			#ip sfx start
sfxGW=4				#forward gw sfx,gw for other nodes 255=NONE

netA=""
netB=""
netSwp="192.168.20" 		#the net need to assign to other network"
netMid="192.168.117" 		#ip for netSwp.x change to netMid.x

ipsA=""
ipsB=""


function netConst(){
    if [ X"$ipsA" != X ];then
	echo "ipsA not None return"
	return
    fi

    echo "in netConst do construct for ipsA,ipsB"
    nets=`ip a | grep 192.168. | awk '{print $2}'`
    netsNum=`echo "$nets" | wc -l`

    if [ $netsNum -ne 2 ];then
	echo "net error, $netsNum not 2: $nets, exit"
	exit
    fi

    netA=`echo $nets | awk '{print $1}'`
    netA=${netA%.*}
    netB=`echo $nets | awk '{print $2}'`
    netB=${netB%.*}

    echo "networks :$netA , $netB"

    for ((i=0; i<nodeNum; i++));do
	let sfx=sfxStart+i
	if [ $sfx == $sfxGW ];then
	    hasGW="True"
	    continue
   	fi
	ipsA="$ipsA $netA.$sfx"
	ipsB="$ipsB $netB.$sfx"
    done

    if [ X$hasGW != X ];then
    	ipsA="$ipsA $netA.$sfxGW"
    	ipsB="$ipsB $netB.$sfxGW"
    fi

    echo "ipsA:$ipsA"
    echo "ipsB:$ipsB"
}

function sshChk(){
    toChk=$1
    echo "in func sshChk"
    for cli in $toChk;do
	echo -n "$cli "
	ssh $cli 'ls 2>&1 >/dev/null'
	ret=$?
	if [ $ret -ne 0 ];then
	    echo "sshChk error,exit"
	    exit
	fi

	echo "sshChk ok"
    done
}

function pingChk(){
    toChk=$1
    echo "in func pingChk"
    for cli in $toChk;do
	echo -n "$cli "
	ping -c 3 $cli 2>&1 >/dev/null
	ret=$?
	if [ $ret -ne 0 ];then
	    echo "pingChk error,exit"
	    exit
	fi
	echo "pingChk ok"
    done
}


function doChange(){
    toCons=$1
    toChanges=$2
    dstNet=$3
    dsts=""
    i=0

    echo "in func doChange"
    for cli in $toCons;do
	((i+=1))
	toCh=$(echo $toChanges | awk "{print \$$i}")
	ipsfx=${toCh##*.}

	if [ X$debug == X ];then
	    ssh $cli systemctl restart NetworkManager
        fi

	inf=`ssh $cli 'ip a' | grep "$toCh/" | awk '{print $NF}'`
	link=`ssh $cli 'nmcli' | grep ": connected to " | grep "$inf" | sed 's/: connect.*//'`

	mdgw=`ssh $cli 'ip r' | grep default | grep -c $link`
	if [ $mdgw -ge 1 ];then
	    gw=`ssh $cli 'ip r' | grep default | awk '{print $3}'`
	    gwsfx=${gw##*.}
	fi

	dsts="$dsts $dstNet.$ipsfx"

	echo "con:$cli,if:$inf,lk:$link,$toCh->$dstNet.$ipsfx,gw:$mdgw,gwsfx:$gwsfx"

	#do modify
	if [ X$debug == X ];then
	    ssh $cli "nmcli connection modify $link ipv4.address $dstNet.$ipsfx/24"
	    if [ $mdgw -ge 1 ];then
		ssh $cli "nmcli connection modify $link ipv4.gateway $dstNet.$gwsfx"
	    fi
	    ssh $cli "nmcli connection down $link;nmcli connection up $link"
	fi
    done

    ipsM="$dsts"
    echo "ipsM:$ipsM"
    if [ X$debug == X ];then
	pingChk "$dsts"
    fi
}

function doSwap(){
    if [ $netSwp == $netA ];then
	doChange "$ipsB" "$ipsA" "$netMid"
	doChange "$ipsM" "$ipsB" "$netSwp"
    else
	doChange "$ipsA" "$ipsB" "$netMid"
	doChange "$ipsM" "$ipsA" "$netSwp"
    fi
}

function usage() {
    echo "Usage: $0 [options]
	Options:
	    -h	    Display this msg
	    -s	    doSwap
	    -c	    doChange
	    -r	    actually run
	"
}

function optParse(){
    while getopts "hscr" opt;do
	case $opt in
	    h)
		usage
		exit 0
		;;
	    s)
		opSwp="True"
		;;
	    c)
		opChange="True"
		;;
	    r)
		debug=""
		;;
	esac
    done

    echo "opSwp:$opSwp,opChange:$opChange,debug:$debug"
}

function main(){
    optParse $@

    exit
    netConst
    sshChk "$ipsA"
    if [ X$opSwp != X ];then
	sshChk "$ipsB"
	doSwap
    elif [ X$opChange != X ];then
	doChange "$ipsA" "$ipsB" "$netMid"
    fi
}

debug="yes"
main $@
