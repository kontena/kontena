#
# Copyright 2016 Kontena, Inc.
#
# All Rights Reserved.
#

name "kontena"
package_name "kontena-cli"
friendly_name "Kontena CLI"
description "Command-line tool for the Kontena Platform"
maintainer "Kontena, Inc."
homepage "https://kontena.io"

# Defaults to C:/kontena on Windows
# and /opt/kontena on all other platforms
install_dir "#{default_root}/#{name}"

build_version File.read('../VERSION').strip
build_iteration 1

# Creates required build directories
dependency "preparation"

# kontena dependencies/components
dependency "kontena-cli"

# Version manifest file
dependency "version-manifest"

exclude "**/.git"
exclude "**/bundler/git"

package :pkg do
  identifier "io.kontena.cli.pkg.kontena"
  signing_identity "Developer ID Installer: Kontena Oy (JJ22T2W355)"
end

package :deb do
  vendor "Kontena, Inc <info@kontena.io>"
end
