#!/bin/bash

# **Internal** Find the internal path for a package
#
# ```
# _pkgpath_for "core/redis"
# ```
_pkgpath_for() {
  hab pkg path $1 | $bb sed -e "s,^$IMAGE_ROOT_FULLPATH,,g"
}


create_filesystem_layout() {
  mkdir -p {bin,sbin,boot,dev,etc,home,lib,mnt,opt,proc,srv,sys}
  mkdir -p boot/grub
  mkdir -p usr/{sbin,bin,include,lib,share,src}
  mkdir -p var/{lib,lock,log,run,spool}
  install -d -m 0750 root 
  install -d -m 1777 tmp
  cp ${program_files_path}/{passwd,shadow,group,issue,profile,locale.sh,hosts,fstab} etc/
  install -Dm755 ${program_files_path}/simple.script usr/share/udhcpc/default.script
  install -Dm755 ${program_files_path}/startup etc/init.d/startup
  install -Dm755 ${program_files_path}/inittab etc/inittab
  hab pkg binlink core/busybox-static bash -d ${PWD}/bin
  hab pkg binlink core/busybox-static login -d ${PWD}/bin
  hab pkg binlink core/busybox-static sh -d ${PWD}/bin
  hab pkg binlink core/busybox-static init -d ${PWD}/sbin
  hab pkg binlink core/hab hab -d ${PWD}/bin

  add_packages_to_path
  setup_init
}

setup_init() {
  install -d -m 0755 etc/rc.d/dhcpcd 
  install -d -m 0755 etc/rc.d/hab
  install -Dm755 ${program_files_path}/udhcpc-run etc/rc.d/dhcpcd/run
  install -Dm755 ${program_files_path}/hab etc/rc.d/hab/run

  for pkg in ${PACKAGES[@]}; do 
    echo "/bin/hab sup load ${pkg} --force" >> etc/rc.d/hab/run
  done
  echo "/bin/hab sup run " >> etc/rc.d/hab/run
}

add_package_to_path() {
  local _pkg=$1

  if [[ -f "${_pkg}/PATH" ]]; then
    local _path=$(cat "${_pkg}/PATH")
    echo "PATH=\${PATH}:${_path}" >> etc/profile.d/hab_path.sh 
  fi
}

add_packages_to_path() {
  local _pkgpath=$(dirname $0)/..
  
  mkdir -p etc/profile.d
    
  if [[ -f "${_pkgpath}/TDEPS" ]]; then 
    for dep in $(cat "${_pkgpath}/TDEPS"); do
      local _deppath=$(_pkgpath_for $dep)
      add_package_to_path $_deppath
    done
  fi
  
  echo "export PATH" >> etc/profile.d/hab_path.sh
}

PACKAGES=($@)
program_files_path=$(dirname $0)/../files

create_filesystem_layout
setup_init