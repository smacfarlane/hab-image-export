pkg_name=mkirfs
pkg_origin=smacfarlane
pkg_version="0.1.0"
pkg_maintainer="The Habitat Maintainers <humans@habitat.sh>"
pkg_license=('Apache-2.0')
pkg_bin_dirs=(bin)
pkg_deps=(core/busybox-static core/hab core/gawk)

do_build() {
  return 0
}

do_install() {
  mkdir -p ${pkg_prefix}/config
  cp -a $PLAN_CONTEXT/filesystem ${pkg_prefix}
  install -m0755 $PLAN_CONTEXT/bin/hab-mkirfs  ${pkg_prefix}/bin/mkirfs
  
  touch ${pkg_prefix}/config/env.sh
  chmod +x ${pkg_prefix}/config/env.sh
  echo "export INITRAMFS_FILESYSTEM=${pkg_prefix}/filesystem" >> ${pkg_prefix}/config/env.sh
}
