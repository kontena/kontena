#
# Copyright 2016 YOUR NAME
#
# All Rights Reserved.
#

name "kontena"
friendly_name "Kontena CLI"
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
dependency "kontena"

# Version manifest file
dependency "version-manifest"

exclude "**/.git"
exclude "**/bundler/git"

package :pkg do
  identifier "io.kontena.pkg.self"
end
