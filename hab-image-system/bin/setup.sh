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

  link_bins
  setup_root_ssh # TODO: Temporary hack, remove me

  install -Dm744 ${program_files_path}/init ${PWD}/sbin/
}

setup_root_ssh() {
  mkdir -p root/.ssh
  chmod 700 root/.ssh
  if [[ -f ${program_files_path}/authorized_keys ]]; then
    install -m 0600 ${program_files_path}/authorized_keys root/.ssh/authorized_keys
  fi
}

link_bins_for() {
  local _pkg=$1

  if [[ -f "${_pkg}/PATH" && -f "${_pkg}/IDENT" ]]; then
    local ident=$(cat ${_pkg}/IDENT)
    # Launcher has a unique PATH, skip it
    if [[ -z "${ident##core/hab-launcher/*}" ]]; then
      echo "Not linking the launcher" 
      continue
    fi

    for path in $(cat "${_pkg}/PATH"| tr ":" "\n"); do  
      local bindir=$(basename $path); 
      mkdir -p /usr/${bindir} 
      for bin in $path/*; do 
        hab pkg binlink $ident "$(basename $bin)" -d ${PWD}/usr/"${bindir}" 
      done
    done
  fi
}

link_bins() {
  local _pkgpath=$(dirname $0)/..
  
  if [[ -f "${_pkgpath}/DEPS" ]]; then 
    for dep in $(cat "${_pkgpath}/DEPS"); do
      local _deppath=$(_pkgpath_for $dep)
      link_bins_for $_deppath
    done
  fi
}

PACKAGES=($@)
program_files_path=$(dirname $0)/../files

create_filesystem_layout
