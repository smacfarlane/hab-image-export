#!/bin/bash

# If the variable `$DEBUG` is set, then print the shell commands as we execute.
if [ -n "${DEBUG:-}" ]; then
  set -x
  export DEBUG
fi

# ## Help

# **Internal** Prints help
print_help() {
  printf -- "$program $version
Habitat Package Image - Create a bootable disk image from a set of Habitat packages
USAGE:
  $program [PKG ..]
"
}

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

# **Internal** Find the internal path for a package
#
# ```
# _pkgpath_for "core/redis"
# ```
_pkgpath_for() {
  hab pkg path $1 | $bb sed -e "s,^$IMAGE_ROOT_FULLPATH,,g"
}

# Return the name of a package including version with - seperators
#
# ```
# package_name_with_version "core/redis"
# "core-redis-3.2.4-20170514150022"
# ```
package_name_with_version() {
  local ident_file=$(find /hab/pkgs/$1 -name IDENT)
  cat $ident_file | awk 'BEGIN { FS = "/" }; { print $1 "-" $2 "-" $3 "-" $4 }'
}

# Creates a file to be used as the disk image with a single full-disk partition
#
# ```
# create_and_partition_raw_image "hab-raw-image"
# ```
create_and_partition_raw_image() {
  local image_name="${1}"
  dd if=/dev/zero of="${image_name}" bs=1M count=2048
  cat <<EOF | fdisk "${image_name}"
n




w
EOF
}

# 
# Create a new temporary workspace and make that our CWD
# Create a file of $SIZE that will be the basis of our image
#   Partition the file
#   Mount the file, and its partition as loopback devices
#   Add a filesystem to the partition 
#   Create a mountpoint for it in the CWD
#   Mount the partition to that directory and make that our new CWD
#     This will be / in our resulting image
#
# The resulting directory tree will look like this:
#   
# ├── $IMAGE_CONTEXT/      # <-- Our workspace root
# │   ├── hab-raw-image    # <-- This is the "raw image" that will be exported
# │   ├── hab-image-root   # <-- This is the mountpoint for the above partition
#                                and is / for the resulting image.
# │   │   ├── bin             
# │   │   ├── etc           
# .....

raw_image() {
  IMAGE_CONTEXT="$($_mktemp_cmd -t -d "${program}-XXXX")"
  pushd $IMAGE_CONTEXT  
  create_raw_image
  popd 
  rm -rf "${IMAGE_CONTEXT}"
}

create_raw_image() {
  local _image_name="hab-raw-image"
  local _image_rootfs_dir="hab-image-root"

  IMAGE_ROOT_FULLPATH="${IMAGE_CONTEXT}/${_image_rootfs_dir}"

  create_and_partition_raw_image "$_image_name"
  # losetup -P flag *should* handle this for us, but for some reason doesn't create the partition devices.
  #  This is a workaround for that
  local _loopback_dev=$(losetup -f ${_image_name} --show)
  local _partition_loopback_dev=$(losetup -o 1048576 -f ${_image_name} --show)
  
  mkfs.ext4 "${_partition_loopback_dev}"
  mkdir "${_image_rootfs_dir}"
  mount "${_partition_loopback_dev}" "${_image_rootfs_dir}"
  pushd "${_image_rootfs_dir}"
 
  populate_image
  install_bootloader "${_loopback_dev}"

  popd
  umount "${_image_rootfs_dir}"
  losetup -d "${_loopback_dev}"
  losetup -d "${_partition_loopback_dev}"

  mv ${_image_name} /src/results/$(package_name_with_version ${PKGS[0]}).raw
}

populate_image() {
  env PKGS="${IMAGE_PKGS[*]}" NO_MOUNT=1 hab studio -r "${PWD}" -t bare new

  create_filesystem_layout
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
  install -Dm755 ${program_files_path}/udhcpc-run etc/rc.d/dhcpcd
  install -Dm755 ${program_files_path}/hab etc/rc.d/hab

  hab pkg binlink core/busybox-static bash -d ${PWD}/bin
  hab pkg binlink core/busybox-static login -d ${PWD}/bin
  hab pkg binlink core/busybox-static sh -d ${PWD}/bin
  hab pkg binlink core/busybox-static init -d ${PWD}/sbin
  hab pkg binlink core/hab hab -d ${PWD}/bin

  add_packages_to_path ${INIT[@]}

  for pkg in ${PKGS[@]}; do 
    echo "hab sup load ${pkg} --force" >> etc/rc.d/hab
  done
  echo "hab sup run &" >> etc/rc.d/hab
}

add_packages_to_path() {
  local _pkgs=($@)
  local _profile_path=""

  for pkg in ${_pkgs[@]}; do 
    local _pkgpath_file="$(_pkgpath_for $pkg)/PATH"
    if [[ -f "${_pkgpath_file#/}" ]]; then
      if [[ -z "${_profile_path}" ]]; then
        _profile_path="$(cat ${_pkgpath_file})"
      else
        _profile_path="${_profile_path}:$(cat ${_pkgpath_file})"
      fi 
    fi
  done
  
  mkdir -p etc/profile.d

  echo "export PATH=\${PATH}:${_profile_path}" >> etc/profile.d/hab_path.sh
}

install_bootloader() {
  local _device="${1}"
  # PARTUUID=$(fdisk -l $IMAGE_CONTEXT/$IMAGE_NAME |grep "Disk identifier" |awk -F "0x" '{ print $2}')
  # echo $PARTUUID
  cat <<EOB  > ${PWD}/boot/grub/grub.cfg 
linux $(hab pkg path ${KERNEL})/boot/bzImage quiet root=/dev/sda1
boot
EOB

  grub-install --modules=part_msdos --boot-directory="${PWD}/boot" "${_device}" 
}

program=$(basename $0)
program_files_path=$(dirname $0)/../files

find_system_commands

KERNEL="core/linux"
INIT=(core/iproute2 core/busybox-static core/util-linux core/coreutils)
PKGS=($@)
IMAGE_NAME="${1//\//-}"  # Turns core/redis into core-redis
IMAGE_PKGS=($@ $KERNEL ${INIT[*]})

if [[ -z "$@" ]]; then
  print_help
  exit_with "You must specify one or more Habitat packages to put in the image." 1
elif [[ "$@" == "--help" ]]; then
  print_help
else

  # Stopgap for testing as we clean this up.

  for pkg in ${IMAGE_PKGS[@]}; do 
    hab pkg install "${pkg}"
  done 

  raw_image $@
fi

