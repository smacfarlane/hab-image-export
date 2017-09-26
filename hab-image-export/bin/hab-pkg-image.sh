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
  dd if=/dev/zero of="${image_name}" bs=1M count="${HAB_IMAGE_SIZE}"
  cat <<EOF | fdisk "${image_name}"
n




w
EOF
}


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
 
  env PKGS="${IMAGE_PKGS[*]}" NO_MOUNT=1 hab studio -r "${PWD}" -t bare new
  hab pkg exec "${HAB_SYSTEM}" setup.sh "${PKGS[*]}"
  install_bootloader "${_loopback_dev}"

  popd
  umount "${_image_rootfs_dir}"
  losetup -d "${_loopback_dev}"
  losetup -d "${_partition_loopback_dev}"

  mv ${_image_name} /src/results/$(package_name_with_version ${PKGS[0]}).raw
}

install_bootloader() {
  local _device="${1}"
  # PARTUUID=$(fdisk -l $IMAGE_CONTEXT/$IMAGE_NAME |grep "Disk identifier" |awk -F "0x" '{ print $2}')
  # echo $PARTUUID
  #  NOTE:  The below line allows you to get terminal output when using qemu-system-x86_64 -serial stdio <image>
  #  linux $(hab pkg path ${HAB_KERNEL})/boot/bzImage quiet root=/dev/sda1 rw console=ttyAMA0  console=ttyS0
  cat <<EOB  > ${PWD}/boot/grub/grub.cfg 
linux $(hab pkg path ${HAB_KERNEL})/boot/bzImage quiet root=/dev/sda1 rw 
boot
EOB

  grub-install --modules=part_msdos --boot-directory="${PWD}/boot" "${_device}" 
}

program=$(basename $0)

find_system_commands

HAB_KERNEL="${HAB_KERNEL:-core/linux}"
HAB_SYSTEM="${HAB_SYSTEM:-${HAB_ORIGIN}/hab-image-system}"
HAB_BOOT="${HAB_BOOT:-core/grub}"
HAB_IMAGE_SIZE="${HAB_IMAGE_SIZE:-512}"
PKGS=($@)

IMAGE_NAME="${1//\//-}"  # Turns core/redis into core-redis
IMAGE_PKGS=($@ $HAB_KERNEL ${HAB_SYSTEM} ${HAB_BOOT})

if [[ -z "$@" ]]; then
  print_help
  exit_with "You must specify one or more Habitat packages to put in the image." 1
elif [[ "$@" == "--help" ]]; then
  print_help
else

  # The method for generating relative paths currently requires the package to be installed in the studio
  for pkg in ${IMAGE_PKGS[@]}; do 
    hab pkg install "${pkg}"
  done 

  raw_image $@
fi

