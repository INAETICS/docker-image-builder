# Helper functions for working with etcdctl in bash.
#
# (C) 2014 INAETICS, <www.inaetics.org> - Apache License v2.

# List child keys for an etcd key
#
# $1 - key, etcd key
# $2 - peers, etcd peers
#
# echos a space seperate list of keys
# returns etcdctl exit code
#
etcd/keys () {
  local key=$1
  local peers=$2

  local code
  local resp
  if [ ! "$peers" == "" ]; then
    resp=($(etcdctl --peers $2 ls $1))
  else
    resp=($(etcdctl ls $1))
  fi
  if [ $? -eq 0 ]; then
    echo "${resp[@]}"
    return 0
  fi
  echo "${resp[@]}" 1>&2
  return 1
}

# Get the value for an etcd key
#
# $1 - key, etcd key
# $2 - peers, etcd peers
#
# returns 
#
etcd/value () {
  local key=$1
  local peers=$2

  local resp
  local resp
  if [ ! "$peers" == "" ]; then
    resp=$(etcdctl --peers $2 get $1)
  else
    resp=$(etcdctl get $1)
  fi
  if [ $? -eq 0 ]; then
    echo $resp
    return 0
  fi
  echo $resp 1>&2
  return 1
}

# List child values for an etcd key
#
# $1 - key, etcd key
# $2 - peers, etcd peers
#
# echos a space seperate list of values
# returns etcdctl exit code
#
etcd/values () {
  local key=$1
  local peers=$2

  local keys
  local code
  keys=$(etcd/keys $key $peers)
  if [ $? -gt 0 ] ; then
    return 1;
  fi

  local values=()
  local resp
  for child in ${keys[@]}; do
    resp=$(etcd/value $child $peers)
    if [ $? -eq 0 ]; then
      values=("${values[@]}" $resp)
    fi
  done
  echo "${values[@]}"
}

#etcd/values /inaetics/apt-cacher-service
