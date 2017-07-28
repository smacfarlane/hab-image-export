pkg_name=dhcp
pkg_origin=core
pkg_version="4.3.5"
pkg_maintainer="The Habitat Maintainers <humans@habitat.sh>"
pkg_license=('ISC')
pkg_upstream_url="http://www.isc.org/downloads/dhcp/"
pkg_description="ISC DHCP is open source software that implements the Dynamic Host Configuration Protocol for connection to an IP network."
pkg_source="https://www.isc.org/downloads/file/${pkg_name}-${pkg_version//./-}"
pkg_filename="${pkg_name}-${pkg_version}.tar.gz"
pkg_shasum="eb95936bf15d2393c55dd505bc527d1d4408289cec5a9fa8abb99f7577e7f954"

pkg_deps=(core/glibc core/perl)
pkg_build_deps=(core/make core/gcc core/file core/diffutils)
pkg_bin_dirs=(bin sbin)

do_before() {
  if [[ ! -f /usr/bin/file ]]; then
    hab pkg binlink core/file file -d /usr/bin
    _clean_file=true
  fi
}

do_end() {
  if [[ -n "${_clean_file}" ]]; then
    rm -f /usr/bin/file
  fi
}

