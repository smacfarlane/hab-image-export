#!/bin/bash


# **Internal** Exit the program with an error message and a status code.
#
# ```sh
# exit_with "Something bad went down" 55
# ```
exit_with() {
  if [ "${HAB_NOCOLORING:-}" = "true" ]; then
    printf -- "ERROR: $1\n"
  else
    case "${TERM:-}" in
      *term | xterm-* | rxvt | screen | screen-*)
        printf -- "\033[1;31mERROR: \033[1;37m$1\033[0m\n"
        ;;
      *)
        printf -- "ERROR: $1\n"
        ;;
    esac
  fi
  exit $2
}

find_system_commands() {
  if $(mktemp --version 2>&1 | grep -q 'GNU coreutils'); then
    _mktemp_cmd=$(command -v mktemp)
  else
    if $(/bin/mktemp --version 2>&1 | grep -q 'GNU coreutils'); then
      _mktemp_cmd=/bin/mktemp
    else
      exit_with "We require GNU mktemp to build images; aborting" 1
    fi
  fi
}

build_image() {
  IMAGE_CONTEXT="$($_mktemp_cmd -t -d "${program}-XXXX")"
  pushd $IMAGE_CONTEXT > /dev/null
  image $@
}


image() {
  IMAGE_NAME="hab_image"
  dd if=/dev/zero of="${IMAGE_NAME}" bs=1M count=2048
  echo -e "n\n\n\n\n\nw" | fdisk $IMAGE_NAME

  # -P flag *should* handle this for us, but for some reason doesn't create the partition devices.
  #  This is a workaround for that
  LOOPDEV=$(losetup -f $IMAGE_NAME --show)
  PART_LOOPDEV=$(losetup -o 1048576 -f $IMAGE_NAME --show)

  mkfs.ext4 $PART_LOOPDEV
  mkdir hab_image_root 
  mount $PART_LOOPDEV hab_image_root
  pushd hab_image_root
  create_filesystem_layout
  copy_hab_stuff
  install_bootloader
  copy_outside
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
  install -Dm755 ${program_files_path}/udhcpc-run etc/rc.d/udhcpc/run

  hab pkg binlink core/bash bash -d ${PWD}/bin
  hab pkg binlink core/bash sh -d ${PWD}/bin

}

copy_hab_stuff() {
  mkdir -p hab 
  cp -a /hab/pkgs hab/
  cp -a /hab/bin hab/
}

install_bootloader() {
  PARTUUID=$(fdisk -l $IMAGE_CONTEXT/$IMAGE_NAME |grep "Disk identifier" |awk -F "0x" '{ print $2}')
  echo $PARTUUID
  cat <<EOB  > ${PWD}/boot/grub/grub.cfg 
linux $(hab pkg path smacfarlane/linux)/boot/bzImage quiet root=/dev/sda1

EOB

  grub-install --modules=part_msdos --boot-directory="${PWD}/boot" ${LOOPDEV} 
}

cleanup() {
  popd >/dev/null
  umount $IMAGE_CONTEXT/hab_image_root
  rm -rf $IMAGE_CONTEXT
  losetup -d $LOOPDEV
  losetup -d $PART_LOOPDEV
}

copy_outside() {
  set -x
  mv $IMAGE_CONTEXT/$IMAGE_NAME /src/results/$IMAGE_NAME-$(date +%Y%m%d%H%M%S)
  set +x
}

program=$(basename $0)
program_files_path=$(dirname $0)/../files

find_system_commands

build_image

cleanup
