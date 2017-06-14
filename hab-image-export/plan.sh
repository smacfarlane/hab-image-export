pkg_name=hab-pkg-image
pkg_origin=core
pkg_version="0.1.0"
pkg_maintainer="The Habitat Maintainers <humans@habitat.sh>"
pkg_license=('Apache-2.0')
pkg_deps=(
  core/grep
  core/coreutils
  core/util-linux
  core/grub
  core/e2fsprogs
  core/hab
  core/gawk
  core/sed
  core/findutils
)
pkg_bin_dirs=(bin)

do_build() {
  return 0
}

do_install() {
  install -vD "${PLAN_CONTEXT}/bin/${pkg_name}.sh" "${pkg_prefix}/bin/${pkg_name}"
  cp -rv "${PLAN_CONTEXT}/files" "${pkg_prefix}/"
}
