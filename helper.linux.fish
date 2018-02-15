set -xg INNERWORKDIR /work
set -xg SCRIPTSDIR /scripts
set -xg PLATFORM linux
set -xg UBUNTUBUILDIMAGE neunhoef/ubuntubuildarangodb
set -xg UBUNTUPACKAGINGIMAGE neunhoef/ubuntupackagearangodb
set -xg ALPINEBUILDIMAGE neunhoef/alpinebuildarangodb

function buildUbuntuBuildImage
  cd $WORKDIR
  cp -a scripts/{buildArangoDB,checkoutArangoDB,checkoutEnterprise,clearWorkDir,downloadStarter,downloadSyncer,runTests,switchBranches}.fish buildUbuntu.docker/scripts
  cd $WORKDIR/buildUbuntu.docker
  docker build -t $UBUNTUBUILDIMAGE .
  rm -f $WORKDIR/buildUbuntu.docker/scripts/*.fish
  cd $WORKDIR
end
function pushUbuntuBuildImage ; docker push $UBUNTUBUILDIMAGE ; end
function pullUbuntuBuildImage ; docker pull $UBUNTUBUILDIMAGE ; end

function buildUbuntuPackagingImage
  cd $WORKDIR
  cp -a scripts/buildDebianPackage.fish buildUbuntuPackaging.docker/scripts
  cd $WORKDIR/buildUbuntuPackaging.docker
  docker build -t $UBUNTUPACKAGINGIMAGE .
  rm -f $WORKDIR/buildUbuntuPackaging.docker/scripts/*.fish
  cd $WORKDIR
end
function pushUbuntuPackagingImage ; docker push $UBUNTUPACKAGINGIMAGE ; end
function pullUbuntuPackagingImage ; docker pull $UBUNTUPACKAGINGIMAGE ; end

function buildAlpineBuildImage
  cd $WORKDIR
  cp -a scripts/buildAlpine.fish buildAlpine.docker/scripts
  cd $WORKDIR/buildAlpine.docker
  docker build -t $ALPINEBUILDIMAGE .
  rm -f $WORKDIR/buildAlpine.docker/scripts/*.fish
  cd $WORKDIR
end
function pushAlpineBuildImage ; docker push $ALPINEBUILDIMAGE ; end
function pullAlpineBuildImage ; docker pull $ALPINEBUILDIMAGE ; end

function remakeImages
  buildUbuntuBuildImage
  pushUbuntuBuildImage
  buildAlpineBuildImage
  pushAlpineBuildImage
  buildUbuntuPackagingImage
  pushUbuntuPackagingImage
end

function runInContainer
  if test -z "$SSH_AUTH_SOCK"
    eval (ssh-agent -c) > /dev/null
    ssh-add ~/.ssh/id_rsa
    set -l agentstarted 1
  else
    set -l agentstarted ""
  end
  docker run -v $WORKDIR/work:$INNERWORKDIR \
             -v $SSH_AUTH_SOCK:/ssh-agent \
             -e SSH_AUTH_SOCK=/ssh-agent \
             -e UID=(id -u) \
             -e GID=(id -g) \
             --rm \
             -e NOSTRIP="$NOSTRIP" \
             -e GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no" \
             -e INNERWORKDIR=$INNERWORKDIR \
             -e MAINTAINER=$MAINTAINER \
             -e BUILDMODE=$BUILDMODE \
             -e PARALLELISM=$PARALLELISM \
             -e STORAGEENGINE=$STORAGEENGINE \
             -e TESTSUITE=$TESTSUITE \
             -e VERBOSEOSKAR=$VERBOSEOSKAR \
             -e ENTERPRISEEDITION=$ENTERPRISEEDITION \
             -e SCRIPTSDIR=$SCRIPTSDIR \
             -e PLATFORM=$PLATFORM \
             $argv
  set -l s $status
  if test -n "$agentstarted"
    ssh-agent -k > /dev/null
    set -e SSH_AUTH_SOCK
    set -e SSH_AGENT_PID
  end
  return $s
end

function checkoutArangoDB
  runInContainer $UBUNTUBUILDIMAGE $SCRIPTSDIR/checkoutArangoDB.fish
  or return $status
  community
end

function checkoutEnterprise
  runInContainer $UBUNTUBUILDIMAGE $SCRIPTSDIR/checkoutEnterprise.fish
  or return $status
  enterprise
end

function switchBranches
  checkoutIfNeeded
  runInContainer $UBUNTUBUILDIMAGE $SCRIPTSDIR/switchBranches.fish $argv
end

function clearWorkdir
  runInContainer $UBUNTUBUILDIMAGE $SCRIPTSDIR/clearWorkdir.fish
end

function buildArangoDB
  checkoutIfNeeded
  runInContainer $UBUNTUBUILDIMAGE $SCRIPTSDIR/buildArangoDB.fish $argv
  set -l s $status
  if test $s != 0
    echo Build error!
    return $s
  end
end

function buildStaticArangoDB
  checkoutIfNeeded
  runInContainer $ALPINEBUILDIMAGE $SCRIPTSDIR/buildAlpine.fish $argv
  set -l s $status
  if test $s != 0
    echo Build error!
    return $s
  end
end

function buildDebianPackage
  # This assumes that a static build has already happened
  # There must be one argument, which is the version number in the
  # format 3.3.3-1
  set -l v $argv[1]
  set -l ch $WORKDIR/work/debian/changelog
  if test -z "$v"
    echo Need one version argument in the form 3.3.3-1.
    return 1
  end

  cd $WORKDIR
  rm -rf $WORKDIR/work/debian
  and if test "$ENTERPRISEEDITION" = "On"
    echo Building enterprise edition debian package...
    cp -a debian.enterprise $WORKDIR/work/debian
    and echo -n "arangodb3e " > $ch
  else
    echo Building community edition debian package...
    cp -a debian.community $WORKDIR/work/debian
    and echo -n "arangodb3 " > $ch
  end
  and echo "($v) UNRELEASED; urgency=medium" >> $ch
  and echo >> $ch
  and echo "  * New version." >> $ch
  and echo >> $ch
  and echo -n " -- ArangoDB <hackers@arangodb.com>  " >> $ch
  and date -R >> $ch
  and runInContainer $UBUNTUPACKAGINGIMAGE $SCRIPTSDIR/buildDebianPackage.fish
  set -l s $status
  if test $s != 0
    echo Error when building a debian package
    return $s
  end
end

function shellInUbuntuContainer
  runInContainer $UBUNTUBUILDIMAGE fish
end

function shellInAlpineContainer
  runInContainer $ALPINEBUILDIMAGE fish
end

function oskar
  checkoutIfNeeded
  runInContainer $UBUNTUBUILDIMAGE $SCRIPTSDIR/runTests.fish
end

function pushOskar
  cd $WORKDIR
  source helper.fish
  git push
  buildUbuntuBuildImage
  pushUbuntuBuildImage
  buildAlpineBuildImage
  pushAlpineBuildImage
  buildUbuntuPackagingImage
  pushUbuntuPackagingImage
end

function updateOskar
  cd $WORKDIR
  git pull
  source helper.fish
  pullUbuntuBuildImage
  pullAlpineBuildImage
  pullUbuntuPackagingImage
end

function downloadStarter
  runInContainer $UBUNTUBUILDIMAGE $SCRIPTSDIR/downloadStarter.fish $argv
end

function downloadSyncer
  runInContainer -e DOWNLOAD_SYNC_USER=$DOWNLOAD_SYNC_USER $UBUNTUBUILDIMAGE $SCRIPTSDIR/downloadSyncer.fish $argv
end

function makeDockerImage
  if test (count $argv) = 0
    echo Must give image name as argument
    return 1
  end
  set -l imagename $argv[1]

  cd $WORKDIR/work/ArangoDB/build/install
  and tar czvf $WORKDIR/arangodb.docker/install.tar.gz *
  if test $status != 0
    echo Could not create install tarball!
    return 1
  end

  cd $WORKDIR/arangodb.docker
  docker build -t $imagename .
end

function buildPackage
  buildDebianPackage $argv
  # buildRpmPackage $argv
  # buildDockerImage $argv
end