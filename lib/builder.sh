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
    _dbg "-> $FUNCNAME - no apt-proxy request"
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
    _dbg "-> $FUNCNAME - no apt-proxy request"
    return 0
  fi
  
  source java-installer/java-settings
  local jdk="${BUILDER_WORKDIR}/$JDK_ARCHIVE"
  if [ ! -f "$jdk" ]; then
    _log "Downloading JDK from $JDK_LOCATION"
    _call curl -L -C - -b "oraclelicense=accept-securebackup-cookie" -o ${jdk}.download $JDK_LOCATION
    if [ $? -gt 0 ]; then
      _log "Failed to download JDK archive"
    else
      _call mv ${jdk}.download $jdk
    fi
  fi
  _log "Inserting JDK install from $jdk"
  _call rsync -va  java-installer $builddir
  _call rsync -av $jdk $1/java-installer
  sed -i "/##JDK_INSTALL/ a\\
        ADD java-installer /tmp/java-installer/\n \
        RUN /tmp/java-installer/java-install; rm -Rf /tmp/java-installer" \
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

  _log "Starting build $builddir"
  _call docker build -t $1 $builddir
  if [ $? -gt 0 ]; then
    _log "Build failed $1"
    return 1
  fi
  _log "Build completed $1"
}
