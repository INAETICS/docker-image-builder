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
    local peers=${2:-$ETCDCTL_PEERS}

    local code
    local resp
    if [ -n "$peers" ]; then
        resp=($(etcdctl --peers "$peers" ls $key 2>&1))
    else
        resp=($(etcdctl ls $key 2>&1))
    fi
    if [ $? -eq 0 ]; then
        echo "${resp[@]}"
        return 0
    else
        echo "Failed to get '$key': ${resp[@]} [$?]!" >&2
        return 1
    fi
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
    local peers=${2:-$ETCDCTL_PEERS}

    local resp
    if [ -n "$peers" ]; then
        resp=$(etcdctl --peers "$peers" get $key 2>/dev/null)
    else
        resp=$(etcdctl get $key 2>/dev/null)
    fi
    if [ $? -eq 0 ]; then
        echo $resp
        return 0
    else
        # No such value...
        return 1
    fi
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
    local peers=${2:-$ETCDCTL_PEERS}

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

# Sets/puts a key/value pair into Etcd.
#   args: KEY - the key to set;
#         VALUE - the value to set;
#         PEERS - (optional) the list of Etcd peers to use.
etcd/put () {
    local key=$1
    local value=$2
    local peers=${3:-$ETCDCTL_PEERS}

    if [ -n "$peers" ]; then
        etcdctl --peers "$peers" set "$key" "$value" >/dev/null 2>&1
    else
        etcdctl set "$key" "$value" >/dev/null 2>&1
    fi
    if [ $? -ne 0 ]; then
        echo "Failed to set '$key' [$?]!" >&2
        return 1
    fi
}

# Initializes the Etcd directory for use with this service
#   args: NS - the Etcd namespace to initialize
#   returns: nothing
etcd/init () {
    local ns=$1
    $(etcdctl ls "$ns" >/dev/null 2>&1)
    if [ $? -ne 0 ]; then
        _log "Dir ${ns} not found, creating one..."
        etcdctl mkdir "$ns" 2>&1 >/dev/null
    fi
}

etcd/mkdir () {
    local ns=$1
    local name=$2
    # Create directory?
    etcdctl ls "$ns/$name" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        etcdctl mkdir "$ns/$name" >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            _log "Failed to create directory..."
            exit $EPUBLISH_FAILED
        fi
    fi
}

###EOF###
