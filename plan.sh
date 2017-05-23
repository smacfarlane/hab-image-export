# This file is the heart of your application's habitat.
# See full docs at https://www.habitat.sh/docs/reference/plan-syntax/

# Required.
# Sets the name of the package. This will be used in along with `pkg_origin`,
# and `pkg_version` to define the fully-qualified package name, which determines
# where the package is installed to on disk, how it is referred to in package
# metadata, and so on.
pkg_name=hab-pkg-image

# Required unless overridden by the `HAB_ORIGIN` environment variable.
# The origin is used to denote a particular upstream of a package.
pkg_origin=smacfarlane

# Required.
# Sets the version of the package.
pkg_version="0.1.0"

# Optional.
# The name and email address of the package maintainer.
# pkg_maintainer="The Habitat Maintainers <humans@habitat.sh>"

# Optional.
# An array of valid software licenses that relate to this package.
# Please choose a license from http://spdx.org/licenses/
# pkg_license=('Apache-2.0')

# Required.
# A URL that specifies where to download the source from. Any valid wget url
# will work. Typically, the relative path for the URL is partially constructed
# from the pkg_name and pkg_version values; however, this convention is not
# required.
pkg_source="http://some_source_url/releases/${pkg_name}-${pkg_version}.tar.gz"

# Optional.
# The resulting filename for the download, typically constructed from the
# pkg_name and pkg_version values.
# pkg_filename="${pkg_name}-${pkg_version}.tar.gz"

# Required if a valid URL is provided for pkg_source or unless do_verify() is overridden.
# The value for pkg_shasum is a sha-256 sum of the downloaded pkg_source. If you
# do not have the checksum, you can easily generate it by downloading the source
# and using the sha256sum or gsha256sum tools. Also, if you do not have
# do_verify() overridden, and you do not have the correct sha-256 sum, then the
# expected value will be shown in the build output of your package.
pkg_shasum="TODO"

# Optional.
# An array of package dependencies needed at runtime. You can refer to packages
# at three levels of specificity: `origin/package`, `origin/package/version`, or
# `origin/package/version/release`.
pkg_deps=(core/bash core/grep core/coreutils core/util-linux smacfarlane/grub smacfarlane/e2fsprogs core/hab core/gawk)

# Optional.
# An array of the package dependencies needed only at build time.
# pkg_build_deps=(core/make core/gcc)

# Optional.
# An array of paths, relative to the final install of the software, where
# libraries can be found. Used to populate LD_FLAGS and LD_RUN_PATH for
# software that depends on your package.
# pkg_lib_dirs=(lib)

# Optional.
# An array of paths, relative to the final install of the software, where
# headers can be found. Used to populate CFLAGS for software that depends on
# your package.
# pkg_include_dirs=(include)

# Optional.
# An array of paths, relative to the final install of the software, where
# binaries can be found. Used to populate PATH for software that depends on
# your package.
pkg_bin_dirs=(bin)

# Optional.
# An array of paths, relative to the final install of the software, where
# pkg-config metadata (.pc files) can be found. Used to populate
# PKG_CONFIG_PATH for software that depends on your package.
# pkg_pconfig_dirs=(lib/pconfig)

# Optional.
# The command for the supervisor to execute when starting a service. You can
# omit this setting if your package is not intended to be run directly by a
# supervisor of if your plan contains a run hook in hooks/run.
# pkg_svc_run="bin/haproxy -f $pkg_svc_config_path/haproxy.conf"

# Optional.
# An associative array representing configuration data which should be gossiped to peers. The keys
# in this array represent the name the value will be assigned and the values represent the toml path
# to read the value.
# pkg_exports=(
#   [host]=srv.address
#   [port]=srv.port
#   [ssl-port]=srv.ssl.port
# )

# Optional.
# An array of `pkg_exports` keys containing default values for which ports that this package
# exposes. These values are used as sensible defaults for other tools. For example, when exporting
# a package to a container format.
# pkg_exposes=(port ssl-port)


# Optional.
# An array of interpreters used in shebang lines for scripts. Specify the
# subdirectory where the binary is relative to the package, for example,
# bin/bash or libexec/neverland, since binaries can be located in directories
# besides bin. This list of interpreters will be written to the metadata
# INTERPRETERS file, located inside a package, with their fully-qualified path.
# Then these can be used with the fix_interpreter function.
# pkg_interpreters=(bin/bash)

# Optional.
# The user to run the service as. The default is hab.
# pkg_svc_user="hab"

# Optional.
# The group to run the service as. The default is hab.
# pkg_svc_group="$pkg_svc_user"

# pkg_description="Some description."
# pkg_upstream_url="http://example.com/project-name"
do_begin() {
  return 0
}

# The default implementation is that the software specified in $pkg_source is
# downloaded, checksum-verified, and placed in $HAB_CACHE_SRC_PATH/$pkgfilename,
# which resolves to a path like /hab/cache/src/filename.tar.gz. You should
# override this behavior if you need to change how your binary source is
# downloaded, if you are not downloading any source code at all, or if your are
# cloning from git. If you do clone a repo from git, you must override
# do_verify() to return 0.
do_download() {
  return 0
}

# The default implementation tries to verify the checksum specified in the plan
# against the computed checksum after downloading the source tarball to disk.
# If the specified checksum doesn't match the computed checksum, then an error
# and a message specifying the mismatch will be printed to stderr. You should
# not need to override this behavior unless your package does not download
# any files.
do_verify() {
  return 0
}

# The default implementation removes the HAB_CACHE_SRC_PATH/$pkg_dirname folder
# in case there was a previously-built version of your package installed on
# disk. This ensures you start with a clean build environment.
do_clean() {
  do_default_clean
}

# The default implementation extracts your tarball source file into
# HAB_CACHE_SRC_PATH. The supported archives are: .tar, .tar.bz2, .tar.gz,
# .tar.xz, .rar, .zip, .Z, .7z. If the file archive could not be found or was
# not supported, then a message will be printed to stderr with additional
# information.
do_unpack() {
  return 0
}

# There is no default implementation of this callback. At this point in the
# build process, the tarball source has been downloaded, unpacked, and the build
# environment variables have been set, so you can use this callback to perform
# any actions before the package starts building, such as exporting variables,
# adding symlinks, and so on.
do_prepare() {
  return 0
}

# The default implementation is to update the prefix path for the configure
# script to use $pkg_prefix and then run make to compile the downloaded source.
# This means the script in the default implementation does
# ./configure --prefix=$pkg_prefix && make. You should override this behavior
# if you have additional configuration changes to make or other software to
# build and install as part of building your package.
do_build() {
  cp -a $PLAN_CONTEXT/bin/${pkg_name}.sh $pkg_name
  cp -a $PLAN_CONTEXT/files .
}

# The default implementation runs nothing during post-compile. An example of a
# command you might use in this callback is make test. To use this callback, two
# conditions must be true. A) do_check() function has been declared, B) DO_CHECK
# environment variable exists and set to true, env DO_CHECK=true.
do_check() {
  return 0
}

# The default implementation is to run make install on the source files and
# place the compiled binaries or libraries in HAB_CACHE_SRC_PATH/$pkg_dirname,
# which resolves to a path like /hab/cache/src/packagename-version/. It uses
# this location because of do_build() using the --prefix option when calling the
# configure script. You should override this behavior if you need to perform
# custom installation steps, such as copying files from HAB_CACHE_SRC_PATH to
# specific directories in your package, or installing pre-built binaries into
# your package.
do_install() {
  install -D $pkg_name $pkg_prefix/bin/$pkg_name
  mkdir -p $pkg_prefix/files
  cp -a files/ $pkg_prefix/

}

# The default implementation is to strip any binaries in $pkg_prefix of their
# debugging symbols. You should override this behavior if you want to change
# how the binaries are stripped, which additional binaries located in
# subdirectories might also need to be stripped, or whether you do not want the
# binaries stripped at all.
do_strip() {
  do_default_strip
}

# There is no default implementation of this callback. This is called after the
# package has been built and installed. You can use this callback to remove any
# temporary files or perform other post-install clean-up actions.
do_end() {
  return 0
}

