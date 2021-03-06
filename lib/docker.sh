# Helper functions to working with Docker in bash.
#
# (C) 2014 INAETICS, <www.inaetics.org> - Apache License v2.



docker/_call_docker () {
  if [ "$DOCKER_HOST" != "" ]; then
    _call docker -H $DOCKER_HOST $@
  else
    _call docker $@
  fi
  return $?
}

# Tests if a repo is alive
#
# This method is also used to determin whether a part of a
# tag refers to a repository so expect dns errors.
#  args: $1 - <repository>
#  return: 0, if the ping succeeds
#    1, if the ping fails
docker/_ping_repo() {
  _dbg "-> $FUNCNAME - args: $@"
  local resp=$(curl --connect-timeout 1 $1/v1/_ping 2>/dev/null)
  if [ "$resp" != "true" ]; then
    _dbg "-> $FUNCNAME - ping failed"
    return 1
  fi
  _dbg "-> $FUNCNAME - ping ok"
  return 0
}

# Parse a nametag
#
# Basically a split on :, but if the actual tag is missing
# it defaults to latest.
#  args: $1 - nametag, <name>[:<tag>]
#  echo: <name> <tag>, if success
#  return: 0, if success
#     1, if fail
docker/_parse_nametag () {
  _dbg "-> $FUNCNAME - args: $@"
  local parts=(${1//:/ })
  local result
  if [ ${#parts[@]} -eq 2 ]; then
    result="${parts[0]} ${parts[1]}"
  elif [ ${#parts[@]} -eq 1 ]; then
    result="${parts[0]} latest"
  fi
  _dbg "-> $FUNCNAME - result: $result"
  echo $result
}

# Parse a docker repository string into something sensible
#   args: $1 - <repository>, [<host>/][<user>/]<name>[:<tag>]
#   echo: <host> <user> <name> <tag>
#   return: 0, if success
#     1, if fail
docker/_parse_repo () {
  _dbg "-> $FUNCNAME - args: $@"
  local parts=(${1//\// })
  local result
  if [ ${#parts[@]} -eq 1 ]; then
    result="central root $(docker/_parse_nametag ${parts[0]})"
  elif [ ${#parts[@]} -eq 2 ]; then
    # No clue how to distinguish between the two. Seens Docker itself
    # also tries a ping. Obviously this will fail when a host is no
    # longer available...
    docker/_ping_repo ${parts[0]}
    if [ $? -eq 0 ]; then
      result="${parts[0]} root $(docker/_parse_nametag ${parts[1]})"
    else
      result="central ${parts[0]} $(docker/_parse_nametag ${parts[1]})"
    fi
  elif [ ${#parts[@]} -eq 3 ]; then
    result="${parts[0]} ${parts[1]} $(docker/_parse_nametag ${parts[2]})"
  else
    _log "Invalid repository parameter: $1"
    return 1
  fi
  _dbg "-> $FUNCNAME - result: $result"
  echo $result
}

# Parse an image name out of a repository string 
#   args: $1 - <repository>, [<host>/][<user>/]<name>[:<tag>]
#   echo: [<user>/]<name>:<tag>
#   return: 0, if success
#     1, if fail
docker/parse_image_name () {
  _dbg "-> $FUNCNAME - args: $@"
  local repo=($(docker/_parse_repo $1))
  if [ ${#repo[@]} -ne 4 ]; then
    _log "Failed to parse repo $1"
    return 1
  fi
  _dbg "-> $FUNCNAME - repo: ${repo[@]}"
  if [ "${repo[1]}" != "root" ]; then
    result="${repo[1]}/${repo[2]}:${repo[3]}"
  else
    result="${repo[2]}:${repo[3]}"
  fi
  _dbg "-> $FUNCNAME - result: $result"
  echo $result
}

# Returns the image id for a name
#   args: $1 - <name>
#   echo: <imageid>
#   return: 0, if success
#     1, if fail
docker/get_image_id () {
  _dbg "-> $FUNCNAME - args: $@"
  local result=$(docker inspect --format='{{.Id}}' $1 2>/dev/null)
  if [ "$result" != "" ]; then
    _dbg "-> $FUNCNAME - image found: $result"
    echo $result
    return 0
  fi
  _dbg "-> $FUNCNAME - image not found"
  return 1
}

# Returns the image name that for an id
#
# If multiple images match the same id the first is returned
#   args: $1 - <image id>
#   echo: <name>
#   return: 0, if found
#     1, if not found
docker/get_image_name () {
  _dbg "-> $FUNCNAME - args: $@"
  local images=($(docker images --no-trunc | grep $1 | awk '{print $1":"$2}'))
  if [ ${#images} -gt 0 ]; then
    _dbg "-> $FUNCNAME - image name: ${images[0]}"
    echo "${images[0]}"
    return 0
  fi
  _dbg "-> $FUNCNAME - image not found"
  return 1
}

# Tags an image to a registry.
#
# If the repo contains a host it will be included in the hosts. Use
# "central" to pull from the Docker Index.
#   args: $1 - <image id>
#     $2 - <repo name>, [<host>/][<user>/]<name>[:<tag>]
#   echo: <repo name>
#   return: 0, if succes
#     1, if failure
docker/tag_image () {
  _dbg "-> $FUNCNAME - args: $@"
  docker/_call_docker tag $1 $2
  if [ $? -eq 0 ]; then
    _dbg "-> $FUNCNAME - tagged"
    echo $2
    return 0
  fi
  _dbg "-> $FUNCNAME - failed"
  return 1
}

# Push an image to a registry
#   args: $1 - <repo name>, [<host>/][<user>/]<name>[:<tag>]
#   echo: <repo name>
#   return: 0, if succes
#     1, if failure
docker/push_image () {
  _dbg "-> $FUNCNAME - args: $@"
  docker/_call_docker push $1
  if [ $? -eq 0 ]; then
    _dbg "-> $FUNCNAME - pushed"
    echo $1
    return 0
  fi
  _dbg "-> $FUNCNAME - failed"
  return 1
}

# Pull an image from a registry
#   args: $1 - <image name>, [<host>/][<user>/]<name>[:<tag>]
#   echo: <docker id>
#   return: 0, if success
#     1, if failure
docker/pull_image () {
  _dbg "-> $FUNCNAME - args: $@"
  docker/_call_docker pull $1
  if [ $? -eq 0 ]; then
    local dockerid=$(docker/get_image_id $1)
    _dbg "-> $FUNCNAME - dockerid: $dockerid"
    echo $dockerid
    return 0
  fi 
  _dbg "-> $FUNCNAME - failed"
  return 1
}

###EOF###
