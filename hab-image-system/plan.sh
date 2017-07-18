pkg_name=hab-image-system
pkg_origin=core
pkg_version="0.1.0"
pkg_maintainer="The Habitat Maintainers <humans@habitat.sh>"
pkg_license=('Apache-2.0')
pkg_deps=(
  core/iproute2
  core/busybox-static
  core/util-linux
  core/coreutils
  core/hab
  core/hab-launcher
  core/hab-sup
  core/eudev
)
pkg_bin_dirs=(bin)

do_build() {
  return 0
}

do_install() {
  install -vD "${PLAN_CONTEXT}/bin/setup.sh" "${pkg_prefix}/bin/setup.sh"
  cp -rv "${PLAN_CONTEXT}/files" "${pkg_prefix}/"
}
