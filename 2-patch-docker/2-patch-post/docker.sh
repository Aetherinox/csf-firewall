#!/bin/bash

# ############################################################################
#   CSF Docker Script
#
#   execute using
#       - ./install.sh instead of 'sh install.sh'
# ############################################################################

export PATH="$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

DOCKER_INT="docker0"
DOCKER_NETWORK="172.17.0.0/16"
NETWORK_MANUAL_MODE=true
NETWORK_ADAPT_NAME="traefik"
DEBUG_ENABLED=false

chain_exists() {
    [ $# -lt 1 -o $# -gt 2 ] && {
        echo "Usage: chain_exists <chain_name> [table]" >&2
        return 1
    }
    local chain_name="$1" ; shift
    [ $# -eq 1 ] && local table="--table $1"
    /usr/sbin/iptables $table -n --list "$chain_name" >/dev/null 2>&1
}

add_to_forward() {
    local docker_int=$1

    if [ `/usr/sbin/iptables -nvL FORWARD | grep ${docker_int} | wc -l` -eq 0 ]; then
        /usr/sbin/iptables -A FORWARD -o ${docker_int} -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
        /usr/sbin/iptables -A FORWARD -o ${docker_int} -j DOCKER
        /usr/sbin/iptables -A FORWARD -i ${docker_int} ! -o ${docker_int} -j ACCEPT
        /usr/sbin/iptables -A FORWARD -i ${docker_int} -o ${docker_int} -j ACCEPT
    fi
}

add_to_nat() {
    local docker_int=$1
    local subnet=$2

    /usr/sbin/iptables -t nat -A POSTROUTING -s ${subnet} ! -o ${docker_int} -j MASQUERADE
    /usr/sbin/iptables -t nat -A DOCKER -i ${docker_int} -j RETURN
}

add_to_docker_isolation() {
    local docker_int=$1

    /usr/sbin/iptables -A DOCKER-ISOLATION-STAGE-1 -i ${docker_int} ! -o ${docker_int} -j DOCKER-ISOLATION-STAGE-2
    /usr/sbin/iptables -A DOCKER-ISOLATION-STAGE-2 -o ${docker_int} -j DROP
}

/usr/sbin/iptables-save | grep -v -- '-j DOCKER' | /usr/sbin/iptables-restore
chain_exists DOCKER && /usr/sbin/iptables -X DOCKER
chain_exists DOCKER nat && /usr/sbin/iptables -t nat -X DOCKER

/usr/sbin/iptables -N DOCKER
/usr/sbin/iptables -N DOCKER-ISOLATION-STAGE-1
/usr/sbin/iptables -N DOCKER-ISOLATION-STAGE-2
/usr/sbin/iptables -N DOCKER-USER

/usr/sbin/iptables -t nat -N DOCKER

/usr/sbin/iptables -A FORWARD -j DOCKER-USER
/usr/sbin/iptables -A FORWARD -j DOCKER-ISOLATION-STAGE-1
add_to_forward ${DOCKER_INT}

/usr/sbin/iptables -t nat -A PREROUTING -m addrtype --dst-type LOCAL -j DOCKER
/usr/sbin/iptables -t nat -A OUTPUT ! -d 127.0.0.0/8 -m addrtype --dst-type LOCAL -j DOCKER
/usr/sbin/iptables -t nat -A POSTROUTING -s ${DOCKER_NETWORK} ! -o ${DOCKER_INT} -j MASQUERADE

bridges=`docker network ls -q --filter='Driver=bridge'`

for bridge in $bridges; do
    if [ "$DEBUG_ENABLED" = true ] ; then
        printf '\n\n :::::::::: BRIDGE :::::::::: \n\n'
    fi

    # BRIDGE ............... : 242441c7d76c
    # DOCKER_NET_INT_1 ..... : docker0
    # SUBNET ............... : 172.17.0.0/16

    # BRIDGE ............... : 63599565ed58
    # DOCKER_NET_INT_1 ..... : br-63599565ed58
    # SUBNET ............... : 172.18.0.0/16

    # docker network inspect -f '{{"'br-$bridge'" | or (index .Options "com.docker.network.bridge.name")}}' $bridge
    # docker network inspect -f '{{"'br-63599565ed58'" | or (index .Options "com.docker.network.bridge.name")}}' 63599565ed58

    DOCKER_NET_INT=`docker network inspect -f '{{"'br-$bridge'" | or (index .Options "com.docker.network.bridge.name")}}' $bridge`
    subnet=`docker network inspect -f '{{(index .IPAM.Config 0).Subnet}}' $bridge`

    if [ "$DEBUG_ENABLED" = true ] ; then
        printf '  BRIDGE ............... : %s\n' "$bridge"
        printf '  DOCKER_NET_INT_1 ..... : %s\n' "$DOCKER_NET_INT"
        printf '  SUBNET ............... : %s\n\n' "$subnet"
    fi

    add_to_nat ${DOCKER_NET_INT} ${subnet}
    add_to_forward ${DOCKER_NET_INT}
    add_to_docker_isolation ${DOCKER_NET_INT}
done

if [ "$DEBUG_ENABLED" = true ] ; then
    printf '\n\n :::::::: CONTAINERS ::::::: \n\n'
fi

containers=`docker ps -q`

if [ `echo ${containers} | wc -c` -gt "1" ]; then
    for container in ${containers}; do

        # CONTAINER ............... : 5b251b810e7d
        # NETMODE ................. : 63599565ed58b275d60087e218e2875aec3c3258976433d061721f0cb666e0b8

        #   docker inspect -f "{{.HostConfig.NetworkMode}}" 5b251b810e7d
        #       returns 63599565ed58b275d60087e218e2875aec3c3258976433d061721f0cb666e0b8
        netmode=`docker inspect -f "{{.HostConfig.NetworkMode}}" ${container}`

        if [ "$DEBUG_ENABLED" = true ] ; then
            printf '\n\n :::::::: CONTAINERS > LIST ::::::: \n\n'
            printf '   CONTAINER ............... : %s\n' "$container"
            printf '   NETMODE ................. : %s\n\n' "$netmode"
        fi

        #
        #   Netmode > Default
        #

        if [ $netmode == "default" ]; then
            DOCKER_NET_INT=${DOCKER_INT}

            #   This will return empty if IP manually assigned from docker-compose.yml for container
            #   docker inspect -f "{{.NetworkSettings.IPAddress}}" 5b251b810e7d

            ipaddr=`docker inspect -f "{{.NetworkSettings.IPAddress}}" ${container}`

        #
        #   Netmode > Other
        #

        else

            #
            #   Network > Manual Mode
            #   This is for users who have manually defined an IP address for each docker container
            #   Must set
            #       - NETWORK_MANUAL_MODE=true
            #       - NETWORK_ADAPT_NAME='network_adapter_name'
            #

            if [ "$NETWORK_MANUAL_MODE" = true ]; then

                #   docker inspect -f "{{with index .NetworkSettings.Networks \"traefik\"}}{{.NetworkID}}{{end}}" 162a8aada1fd | cut -c -12
                #
                #   returns IP
                #   docker inspect -f "{{with index .NetworkSettings.Networks \"traefik\"}}{{.IPAddress}}{{end}}" 162a8aada1fd | cut -c -12

                bridge=$(docker inspect -f "{{with index .NetworkSettings.Networks \"${NETWORK_ADAPT_NAME}\"}}{{.NetworkID}}{{end}}" ${container} | cut -c -12)

                #   docker network inspect -f '{{"'br-63599565ed58'" | or (index .Options "com.docker.network.bridge.name")}}' 63599565ed58
                DOCKER_NET_INT=`docker network inspect -f '{{"'br-$bridge'" | or (index .Options "com.docker.network.bridge.name")}}' $bridge`

                #   docker inspect -f "{{with index .NetworkSettings.Networks \"traefik\"}}{{.IPAddress}}{{end}}" 162a8aada1fd
                ipaddr=`docker inspect -f "{{with index .NetworkSettings.Networks \"${NETWORK_ADAPT_NAME}\"}}{{.IPAddress}}{{end}}" ${container}`
                
                if [ "$DEBUG_ENABLED" = true ] ; then
                    printf '   BRIDGE .................. : %s\n' "$bridge"
                    printf '   DOCKER_NET_INT_2 ........ : %s\n' "$DOCKER_NET_INT"
                    printf '   IPPADDR ................. : %s\n\n' "$ipaddr"
                fi

            else
                bridge=$(docker inspect -f "{{with index .NetworkSettings.Networks \"${netmode}\"}}{{.NetworkID}}{{end}}" ${container} | cut -c -12)
                DOCKER_NET_INT=`docker network inspect -f '{{"'br-$bridge'" | or (index .Options "com.docker.network.bridge.name")}}' $bridge`
                ipaddr=`docker inspect -f "{{with index .NetworkSettings.Networks \"${netmode}\"}}{{.IPAddress}}{{end}}" ${container}`
            fi
        fi

        rules=`docker port ${container} | sed 's/ //g'`

        if [ `echo ${rules} | wc -c` -gt "1" ]; then
            for rule in ${rules}; do
                src=`echo ${rule} | awk -F'->' '{ print $2 }'`
                dst=`echo ${rule} | awk -F'->' '{ print $1 }'`

                src_ip=`echo ${src} | sed 's|^\(.*\):.*$|\1|'`
                src_port=`echo ${src} | awk -F':' '{ print $2 }'`

                dst_port=`echo ${dst} | awk -F'/' '{ print $1 }'`
                dst_proto=`echo ${dst} | awk -F'/' '{ print $2 }'`

                /usr/sbin/iptables -A DOCKER -d ${ipaddr}/32 ! -i ${DOCKER_NET_INT} -o ${DOCKER_NET_INT} -p ${dst_proto} -m ${dst_proto} --dport ${dst_port} -j ACCEPT
                /usr/sbin/iptables -t nat -A POSTROUTING -s ${ipaddr}/32 -d ${ipaddr}/32 -p ${dst_proto} -m ${dst_proto} --dport ${dst_port} -j MASQUERADE

                iptables_opt_src=""
                if [ ${src_ip} != "0.0.0.0" ]; then
                    iptables_opt_src="-d ${src_ip}/32 "
                fi

                #   Support for IPv4
                if [[ ${src_ip} =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    /usr/sbin/iptables -t nat -A DOCKER ${iptables_opt_src}! -i ${DOCKER_NET_INT} -p ${dst_proto} -m ${dst_proto} --dport ${src_port} -j DNAT --to-destination ${ipaddr}:${dst_port}
                fi
            done
        fi
    done
fi

/usr/sbin/iptables -A DOCKER-ISOLATION-STAGE-1 -j RETURN
/usr/sbin/iptables -A DOCKER-ISOLATION-STAGE-2 -j RETURN
/usr/sbin/iptables -A DOCKER-USER -j RETURN

if [ `/usr/sbin/iptables -t nat -nvL DOCKER | grep ${DOCKER_INT} | wc -l` -eq 0 ]; then
    /usr/sbin/iptables -t nat -I DOCKER -i ${DOCKER_INT} -j RETURN
fi
