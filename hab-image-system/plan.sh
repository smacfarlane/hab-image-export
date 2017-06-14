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
)

do_build() {
  return 0
}

do_install() {
  return 0
  install -vD "${PLAN_CONTEXT}/bin/${pkg_name}.sh" "${pkg_prefix}/bin/${pkg_name}"
  cp -rv "${PLAN_CONTEXT}/files" "${pkg_prefix}/"
}
