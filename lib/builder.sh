# Helper functions for building docker images
#
# (C) 2014 INAETICS, <www.inaetics.org> - Apache License v2.

# Process the APT_PROXY directive in a Dockerfile
#  args: $1, <dir>
#  return: 0, if success
#    1, if fail 
builder/_process_aptproxy () {
  _dbg "-> $FUNCNAME - args: $@"
  _call grep "##APT_PROXY" $1/Dockerfile
  if [ $? -gt 0 ]; then
    _dbg "-> $FUNCNAME - no apt-proxy directive found "
    return 0
  fi
  _log "Dockerfile requests Apt proxy"
  if [ "$2" == "" ]; then 
    _log "No Apt Proxy available"
    return 0
  fi
  _log "Inserting Apt Proxy at $2"
  sed -i "/##APT_PROXY/ a\\
    RUN echo \"Acquire::http::Proxy \\\\\"http://${2}\\\\\";\" \
      > /etc/apt/apt.conf.d/01proxy" \
      $1/Dockerfile
  return $?
}

# Process the JDK_INSTALL directive in a Dockerfile
#  args: $1, <dir>
#  return: 0, if success
#    1, if fail 
builder/_process_jdkinstall () {
  _dbg "-> $FUNCNAME - args: $@"
  _call grep "##JDK_INSTALL" $1/Dockerfile
  if [ $? -gt 0 ]; then
    _dbg "-> $FUNCNAME - no jdk install directive found"
    return 0
  fi
  
  source ${BUILDER_HOMEDIR}/java-installer/java-settings
  local archive="${BUILDER_WORKDIR}/$JDK_ARCHIVE"
  if [ ! -f "$archive" ]; then
    _log "Downloading JDK archive from $JDK_LOCATION"
    _call curl -L -C - -b "oraclelicense=accept-securebackup-cookie" -o ${archive}.download $JDK_LOCATION
    if [ $? -gt 0 ]; then
      _log "Failed to download JDK archive"
    else
      _call mv ${archive}.download $archive
    fi
  fi
  _log "Inserting JDK install from $archive"
  _call rsync -va  ${BUILDER_HOMEDIR}/java-installer $1
  _call rsync -av $archive $1/java-installer
  sed -i "/##JDK_INSTALL/ a\\
        ADD java-installer /tmp/java-installer/\n \
        RUN /tmp/java-installer/java-install; rm -Rf /tmp/java-installer" \
        $1/Dockerfile
  return $?
}

# Process the ETCDCTL_INSTALL directive in a Dockerfile
#  args: $1, <dir>
#  return: 0, if success
#    1, if fail 
builder/_process_etcdctlinstall () {
  _dbg "-> $FUNCNAME - args: $@"
  _call grep "##ETCDCTL_INSTALL" $1/Dockerfile
  if [ $? -gt 0 ]; then
    _dbg "-> $FUNCNAME - no etcdctl install directive"
    return 0
  fi

  source ${BUILDER_HOMEDIR}/etcdctl-installer/etcdctl-settings
  local archive="${BUILDER_WORKDIR}/$ETCDCTL_ARCHIVE"
  if [ ! -f "$archive" ]; then
    _log "Downloading ETCD archive from $ETCDCTL_LOCATION"
    _call curl -L -C - -o ${archive}.download $ETCDCTL_LOCATION
    if [ $? -gt 0 ]; then
      _log "Failed to download ETCD archive"
    else
      _call mv ${archive}.download $archive
    fi
  fi
  _log "Inserting ETCD archive from $archive"
  _call rsync -va  ${BUILDER_HOMEDIR}/etcdctl-installer $1
  _call rsync -av $archive $1/etcdctl-installer
  sed -i "/##ETCDCTL_INSTALL/ a\\
        ADD etcdctl-installer /tmp/etcdctl-installer/\n \
        RUN /tmp/etcdctl-installer/etcdctl-install; rm -Rf /tmp/etcdctl-installer" \
        $1/Dockerfile
  return $?
}


# Build a docker image
#  args: $1, <name>, image name
#    $2 - <dir>, image dir
#    $3 - <aptcacher>, if available
#  return: 0, if success
#    1, if fail 
#FIXME needs tag support
builder/build_image () {
  _dbg "-> $FUNCNAME - args: $@"

  _log "Build image $1 from $2"
  if [ "$1" == "" ]; then
    _log "Image name reguired!"
    return 1
  fi
  if [ ! -d "$2" ]; then 
    _log "No such dir: $2"
    return 1
  fi
  if [ ! -f "$2/Dockerfile" ]; then
    _log "No Dockerfile found: $2"
    return 1
  fi

  local builddir=$(_get_build_dir $1)
  _log "Synchronizing resources $builddir"
  _call rsync -va --exclude="tools" --exclude=".git" --exclude=".vagrant" $2/* $builddir

  builder/_process_aptproxy $builddir $3
  builder/_process_jdkinstall $builddir $3
  builder/_process_etcdctlinstall $builddir $3

  _log "Starting build $builddir"
  _call docker build -t $1 $builddir
  if [ $? -gt 0 ]; then
    _log "Build failed $1"
    return 1
  fi
  _log "Build completed $1"
}
