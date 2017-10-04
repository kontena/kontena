#
# Copyright 2014 Chef Software, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

name "liblzma"
default_version "5.2.3"

license "Public-Domain"
license_file "COPYING"
skip_transitive_dependency_licensing true

version("5.2.2") { source md5: "7cf6a8544a7dae8e8106fdf7addfa28c" }
version("5.2.3") { source md5: "ef68674fb47a8b8e741b34e429d86e9d" }

source url: "http://tukaani.org/xz/xz-#{version}.tar.gz",
       unsafe: true # accept https -> https redirects from sourceforge

relative_path "xz-#{version}"

build do
  env = with_standard_compiler_flags(with_embedded_path)
  # liblzma properly uses CFLAGS for C compilation and CPPFLAGS for common
  # flags used across tools such as windres.  Don't put anything in it
  # that can be misinterpreted by windres.
  env["CPPFLAGS"] = "-I#{install_dir}/embedded/include" if windows?

  config_command = [
    "--disable-debug",
    "--disable-dependency-tracking",
    "--disable-doc",
    "--disable-scripts",
  ]
  config_command << "--disable-nls" if windows?

  configure(*config_command, env: env)

  make "install", env: env
end
