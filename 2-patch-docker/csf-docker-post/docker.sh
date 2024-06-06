#!/bin/bash

export PATH="$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

chain_exists() {
    [ $# -lt 1 -o $# -gt 2 ] && {
        echo "Usage: chain_exists <chain_name> [table]" >&2
        return 1
    }
    local chain_name="$1" ; shift
    [ $# -eq 1 ] && local table="--table $1"
    iptables $table -n --list "$chain_name" >/dev/null 2>&1
}

add_to_forward() {
    local docker_int=$1

    if [ `iptables -nvL FORWARD | grep ${docker_int} | wc -l` -eq 0 ]; then
        iptables -A FORWARD -o ${docker_int} -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
        iptables -A FORWARD -o ${docker_int} -j DOCKER
        iptables -A FORWARD -i ${docker_int} ! -o ${docker_int} -j ACCEPT
        iptables -A FORWARD -i ${docker_int} -o ${docker_int} -j ACCEPT
    fi
}

add_to_nat() {
    local docker_int=$1
    local subnet=$2

    iptables -t nat -A POSTROUTING -s ${subnet} ! -o ${docker_int} -j MASQUERADE
    iptables -t nat -A DOCKER -i ${docker_int} -j RETURN
}

add_to_docker_isolation() {
    local docker_int=$1

    iptables -A DOCKER-ISOLATION-STAGE-1 -i ${docker_int} ! -o ${docker_int} -j DOCKER-ISOLATION-STAGE-2
    iptables -A DOCKER-ISOLATION-STAGE-2 -o ${docker_int} -j DROP
}

DOCKER_INT="docker0"
DOCKER_NETWORK="172.17.0.0/16"

iptables-save | grep -v -- '-j DOCKER' | iptables-restore
chain_exists DOCKER && iptables -X DOCKER
chain_exists DOCKER nat && iptables -t nat -X DOCKER

iptables -N DOCKER
iptables -N DOCKER-ISOLATION-STAGE-1
iptables -N DOCKER-ISOLATION-STAGE-2
iptables -N DOCKER-USER

iptables -t nat -N DOCKER

iptables -A FORWARD -j DOCKER-USER
iptables -A FORWARD -j DOCKER-ISOLATION-STAGE-1
add_to_forward ${DOCKER_INT}

iptables -t nat -A PREROUTING -m addrtype --dst-type LOCAL -j DOCKER
iptables -t nat -A OUTPUT ! -d 127.0.0.0/8 -m addrtype --dst-type LOCAL -j DOCKER
iptables -t nat -A POSTROUTING -s ${DOCKER_NETWORK} ! -o ${DOCKER_INT} -j MASQUERADE

bridges=`docker network ls -q --filter='Driver=bridge'`

for bridge in $bridges; do
    DOCKER_NET_INT=`docker network inspect -f '{{"'br-$bridge'" | or (index .Options "com.docker.network.bridge.name")}}' $bridge`
    subnet=`docker network inspect -f '{{(index .IPAM.Config 0).Subnet}}' $bridge`

    add_to_nat ${DOCKER_NET_INT} ${subnet}
    add_to_forward ${DOCKER_NET_INT}
    add_to_docker_isolation ${DOCKER_NET_INT}
done

containers=`docker ps -q`

if [ `echo ${containers} | wc -c` -gt "1" ]; then
    for container in ${containers}; do
        netmode=`docker inspect -f "{{.HostConfig.NetworkMode}}" ${container}`
        if [ $netmode == "default" ]; then
            DOCKER_NET_INT=${DOCKER_INT}
            ipaddr=`docker inspect -f "{{.NetworkSettings.IPAddress}}" ${container}`
        else
            bridge=$(docker inspect -f "{{with index .NetworkSettings.Networks \"${netmode}\"}}{{.NetworkID}}{{end}}" ${container} | cut -c -12)
            DOCKER_NET_INT=`docker network inspect -f '{{"'br-$bridge'" | or (index .Options "com.docker.network.bridge.name")}}' $bridge`
            ipaddr=`docker inspect -f "{{with index .NetworkSettings.Networks \"${netmode}\"}}{{.IPAddress}}{{end}}" ${container}`
        fi

        rules=`docker port ${container} | sed 's/ //g'`

        if [ `echo ${rules} | wc -c` -gt "1" ]; then
            for rule in ${rules}; do
                src=`echo ${rule} | awk -F'->' '{ print $2 }'`
                dst=`echo ${rule} | awk -F'->' '{ print $1 }'`

                src_ip=`echo ${src} | awk -F':' '{ print $1 }'`
                src_port=`echo ${src} | awk -F':' '{ print $2 }'`

                dst_port=`echo ${dst} | awk -F'/' '{ print $1 }'`
                dst_proto=`echo ${dst} | awk -F'/' '{ print $2 }'`

                iptables -A DOCKER -d ${ipaddr}/32 ! -i ${DOCKER_NET_INT} -o ${DOCKER_NET_INT} -p ${dst_proto} -m ${dst_proto} --dport ${dst_port} -j ACCEPT

                iptables -t nat -A POSTROUTING -s ${ipaddr}/32 -d ${ipaddr}/32 -p ${dst_proto} -m ${dst_proto} --dport ${dst_port} -j MASQUERADE

                iptables_opt_src=""
                if [ ${src_ip} != "0.0.0.0" ]; then
                    iptables_opt_src="-d ${src_ip}/32 "
                fi
                iptables -t nat -A DOCKER ${iptables_opt_src}! -i ${DOCKER_NET_INT} -p ${dst_proto} -m ${dst_proto} --dport ${src_port} -j DNAT --to-destination ${ipaddr}:${dst_port}
            done
        fi
    done
fi

iptables -A DOCKER-ISOLATION-STAGE-1 -j RETURN
iptables -A DOCKER-ISOLATION-STAGE-2 -j RETURN
iptables -A DOCKER-USER -j RETURN

if [ `iptables -t nat -nvL DOCKER | grep ${DOCKER_INT} | wc -l` -eq 0 ]; then
    iptables -t nat -I DOCKER -i ${DOCKER_INT} -j RETURN
fi
