# Helper functions to working with Docker in bash.
#
# (C) 2014 INAETICS, <www.inaetics.org> - Apache License v2.

docker/_list_images () {
    docker images | awk '{if(NR>1)print $1":"$2}'
}

docker/_ping_repo() {
    local host=$1

    local resp
    resp=$(curl --connect-timeout 1 $host/v1/_ping 2>/dev/null)
    if [ $? -gt 0 ] || [ "$resp" != "true" ]; then
        return 1
    fi
    return 0
}

docker/_parse_repo () {
    local repo=$1
    local parts=(${repo//\// })
    local host; local user; local nametag; local name; local tag

    if [ ${#parts[@]} -eq 1 ]; then
        host="central"
        user="root"
        nametag="${parts[0]}"
    elif [ ${#parts[@]} -eq 2 ]; then
        # No clue how to distinguish between the two. Seens Docker itself
        # also tries a ping. Obviously this will fail when a host is no
        # longer available...
        docker/_ping_repo ${parts[0]}
        if [ $? -eq 0 ]; then
            host="${parts[0]}"
            user="root"
            nametag="${parts[1]}"
        else
            host="central"
            user="${parts[0]}"
            nametag="${parts[1]}"
        fi
    elif [ ${#parts[@]} -eq 3 ]; then
        host="${parts[0]}"
        user="${parts[1]}"
        nametag="${parts[2]}"
    else
        echo "Invalid repository parameter: $repo!" >&2
        return 1
    fi

    if [[ $nametag =~ : ]]; then
        name="${nametag//:*/}"
        tag="${nametag//*:/}"
    else
        name="$nametag"
        tag="latest"
    fi

    echo "$host $user $name $tag"
}

docker/_get_image_spec () {
    local repo
    repo=($(docker/_parse_repo $1))
    if [ $? -ne 0 ]; then
        return 1
    fi

    local hosts=(${@:2})
    local host=${repo[0]}
    local user=${repo[1]}
    local name=${repo[2]}
    local tag=${repo[3]}

    if [ ! "${host}" == "central" ]; then
        hosts=( ${hosts[@]/${host}/} )
        hosts=( "${host}" "${hosts[@]}" )
    fi

    local imgpath="$user/$name:$tag"
    if [ "${user}" == "root" ]; then
        imgpath="$name:$tag"
    fi

    echo "$imgpath ${hosts[@]}"
}

# Returns the image ID from Docker
#   args: IMG_NAME - the name of the image to fetch the ID for.
#   returns: the full image ID.
docker/get_image_id () {
    local img_name=$1

    docker inspect --format='{{.Id}}' $img_name 2>/dev/null
}

# Return first matching image (if any)
#   args: IMG_NAME - the (partial) name of the image to find.
#   returns: the full image name.
docker/find_image () {
    local repo
    repo=($(docker/_parse_repo $1))
    if [ $? -gt 0 ]; then
        return 1
    fi

    local images=($(docker/_list_images))
    for image in "${images[@]}"; do
        local parsed=($(docker/_parse_repo ${image}))
        if [ "${repo[1]}" == "${parsed[1]}" ] \
             && [ "${repo[2]}" == "${parsed[2]}" ] \
             && [ "${repo[3]}" == "${parsed[3]}" ]; then
            echo "${image}"
            return 0
        fi
    done
    return 1
}

# Return list of matching images
#
docker/find_images () {
    local repo
    repo=($(docker/_parse_repo $1))
    if [ $? -gt 0 ]; then
        return 1
    fi

    local images=($(docker/_list_images))
    for image in "${images[@]}"; do
        local parsed=($(docker/_parse_repo ${image}))
        if [ "${repo[1]}" == "${parsed[1]}" ] \
             && [ "${repo[2]}" == "${parsed[2]}" ] \
             && [ "${repo[3]}" == "${parsed[3]}" ]; then
            echo "${image}"
        fi
    done
    return 0
}

# Tags an image to a registry.
#
# If the repo contains a host it will be included in the hosts. Use
# "central" to pull from the Docker Index.
#   args: IMG_ID - the image ID to tag;
#         REPO - the registry specification [<host>/][<user>/]<name>[:<tag>];
#         HOST - the registry hosts [<host>[ <host>]].
#
# examples:
#
# docker/tag 172.17.8.100:5000/inaetics/apt-cacher-service
# docker/tag inaetics/apt-cacher-service 172.17.8.100:5000
# docker/tag 172.17.8.100:5001/inaetics/apt-cacher-service "172.17.8.100:5002 central"
#
docker/tag () {
    local img_id=$1
    local spec
    spec=($(docker/_get_image_spec ${@:2}))
    if [ $? -gt 0 ]; then
        return 1
    fi

    local imgpath=${spec[0]}
    local hosts=(${spec[@]:1})

    for host in ${hosts[@]}; do
        local imgspec="$host/$imgpath"
        if [ "${host}" == "central" ]; then
            imgspec="$imgpath"
        fi
        echo "Tagging image ${img_id:0:12} to $imgspec..." >&2
        docker tag $img_id $imgspec >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo "Tagging $imgspec failed [$?]!" >&2
            return 1
        fi
    done
}

# Push an image to all hosts
#
# If the repo contains a host it will be included in the hosts. Use
# "central" to push to the Docker Index.
#
# param repo  : [<host>/][<user>/]<name>[:<tag>]
# param hosts : [<host>[ <host>]]
#
# examples:
#
# docker/push_image 172.17.8.100:5000/inaetics/apt-cacher-service
# docker/push_image inaetics/apt-cacher-service 172.17.8.100:5000
#
docker/push_image () {
    local spec
    spec=($(docker/_get_image_spec $@))
    if [ $? -gt 0 ]; then
        return 1
    fi

    local imgpath=${spec[0]}
    local hosts=(${spec[@]:1})

    for host in ${hosts[@]}; do
        local imgspec="$host/$imgpath"
        if [ "${host}" == "central" ]; then
            imgspec="$imgpath"
        fi

        echo "Pushing image $imgspec..." >&2
        docker push $imgspec >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo "Failed to push image: $imgspec [$?]!" >&2
        fi
    done
    return 0
}

# Pull an image from any host
#
# If the repo contains a host it will be included in the hosts. Use
# "central" to pull from the Docker Index.

# param repo  : [<host>/][<user>/]<name>[:<tag>]
# param hosts : [<host>[ <host>]]
#
# examples:
#
# docker/pull_image 172.17.8.100:5000/inaetics/apt-cacher-service
# docker/pull_image inaetics/apt-cacher-service 172.17.8.100:5000
# docker/pull_image 172.17.8.100:5001/inaetics/apt-cacher-service "172.17.8.100:5002 central"
#
docker/pull_image () {
    local spec
    spec=($(docker/_get_image_spec $@))
    if [ $? -gt 0 ]; then
        return 1
    fi

    local imgpath=${spec[0]}
    local hosts=(${spec[@]:1})

    for host in ${hosts[@]}; do
        local imgspec="$host/$imgpath"
        if [ "${host}" == "central" ]; then
            imgspec="$imgpath"
        fi

        echo "Pulling image: $imgspec..." >&2
        docker pull $imgspec >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo $imgspec
            return 0
        else
            echo "Failed to pull image: $imgspec [$?]!" >&2
        fi
    done

    echo "Failed to pull image from any repository" >&2
    return 1
}

###EOF###
