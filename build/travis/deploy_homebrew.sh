#!/bin/sh

# Autogenerates a homebrew formula and a PR upon a tag build

hub() {
  $CWD/brew/tmp/hub $@
}

install_hub() {
  mkdir tmp 2> /dev/null
  if $(uname|grep Darwin > /dev/null); then
    curl -sL https://github.com/github/hub/releases/download/v2.2.9/hub-darwin-amd64-2.2.9.tgz | tar xzO > $CWD/brew/tmp/hub
  else
    curl -sL https://github.com/github/hub/releases/download/v2.2.9/hub-linux-amd64-2.2.9.tgz | tar xzO > $CWD/brew/tmp/hub
  fi

  chmod +x tmp/hub
  $CWD/brew/tmp/hub --help > /dev/null
}

clone_repositories() {
  #rm -rf brew/homebrew-core 2> /dev/null
  #rm -rf brew/homebrew-kontena 2> /dev/null

  # Clone and sync the homebrew-core fork
  git clone git@github.com:Homebrew/homebrew-core.git homebrew-core
  cd homebrew-core
  git checkout master
  git remote add fork git@github.com:kontena/homebrew-core.git
  #git push -f fork master
  cd ..

  # Clone the brew tap repository
  git clone git@github.com:kontena/homebrew-kontena.git homebrew-kontena
}

prerelease() {
  echo "Working in pre-release mode"
  # Copy the current stable formula over the tap formula
  cp homebrew-core/Formula/kontena.rb homebrew-kontena/Formula/kontena.rb

  cd homebrew-kontena/Formula

  # Add a devel block, alter the "if build.head?" to also check for build.devel?
  cat << EOB | ruby - $CLI_VERSION $LONG_HASH
    formula = File.read('kontena.rb')
    devel_block = [
      "  devel do",
      "    url \"https://github.com/kontena/kontena.git\",",
      "        :tag => \"v#{ARGV[0]}\",",
      "        :revision => \"#{ARGV[1]}\"",
      "    version \"#{ARGV[0]}\"",
      "  end",
      ""
    ].join("\n")

    bottle_block = formula.scan(/^  \w+ do$.+?  end$/m).find { |blk| blk.start_with?('  bottle do') }
    abort "Error parsing kontena.rb, 'bottle do' block not found" if bottle_block.nil?
    formula[bottle_block] = "#{devel_block}\n#{bottle_block}"
    formula["if build.head?"] = "if build.head? || build.devel?"
    File.write('kontena.rb', formula)
EOB

  git add kontena.rb
  git commit -m "Devel $CLI_VERSION"
  git tag $CLI_VERSION
  #git push --tags origin master
}

stable() {
  echo "Working in stable mode"
  cd homebrew-kontena/Formula

  # Build a list of gem dependencies and figure out their sha256 sums

  # Create a dummy gemfile, copy gemspec, VERSION and version.rb in place
  mkdir tmp
  cat << EOB > tmp/Gemfile
source "https://rubygems.org"
gemspec
gem "kontena-plugin-cloud"
EOB
  cp $CWD/../../cli/kontena-cli.gemspec tmp
  cp $CWD/../../cli/VERSION tmp
  mkdir -p tmp/lib/kontena/cli
  cp $CWD/../../cli/lib/kontena/cli/version.rb tmp/lib/kontena/cli

  cd tmp
  gem install --no-document bundler

  # Install all the gems into gems/
  bundle install --standalone --path gems

  echo "Doing resources ..."

  # Scan the gems dir, use rubygems to figure out the shasums
  cat << EOB | ruby > resources.rb
    require 'open-uri'
    Dir["gems/ruby/*/gems/*"].select { |p| File.directory?(p) }.each do |path|
      gem_name = File.basename(path)[/^(.+?)\-\d+\./, 1]
      gem_version = File.basename(path)[/\-(\d+\..*)/, 1]
      warn "Could not figure out a gem name for #{path}" unless gem_name
      warn "Could not figure out a gem version for #{path}" unless gem_version
      abort "Can't continue" unless gem_name && gem_version

      sha = open("https://rubygems.org/gems/#{gem_name}/versions/#{gem_version}").read[/<div class="gem__sha">(.+?)<\/div>/m, 1].strip
      puts
      puts "    resource \"#{gem_name}\" do"
      puts "      url \"https://rubygems.org/gems/#{gem_name}-#{gem_version}.gem\""
      puts "      sha256 \"#{sha}\""
      puts "    end"
    end
EOB

  echo "Done"

  cd ..

  echo "Modifying tap formula .."
  # Modify the tap formula. Remove now outdated "bottle do" block
  # and update the "stable do" block with current version and
  # resource sha's.
  cat << EOB | ruby - $CLI_VERSION $LONG_HASH
    formula = File.read('kontena.rb')
    new_stable_block = [
      "  stable do",
      "    url \"https://github.com/kontena/kontena.git\",",
      "        :tag => \"v#{ARGV[0]}\",",
      "        :revision => \"#{ARGV[1]}\"",
    ].join("\n")
    new_stable_block += "\n" + File.read('tmp/resources.rb')
    new_stable_block += "  end\n"

    stable_block = formula.scan(/^  \w+ do$.+?  end$/m).find { |blk| blk.start_with?('  stable do') }
    bottle_block = formula.scan(/^  \w+ do$.+?  end$/m).find { |blk| blk.start_with?('  bottle do') }
    abort "Error parsing kontena.rb, 'stable do' block not found" if stable_block.nil?
    if bottle_block
      formula[bottle_block] = ""
    else
      warn "There was no 'bottle do' block in the formula."
    end
    formula[stable_block] = new_stable_block
    File.write('kontena.rb', formula)
EOB
  echo "Done"
  git add kontena.rb
  #git commit -m "Stable $CLI_VERSION"
  #git tag $CLI_VERSION
  #git push --tags origin master
  cd ../..

  # Do the same thing for the homebrew-core fork
  cd homebrew-core
  cd Formula
  cat << EOB | ruby - $CLI_VERSION $LONG_HASH
    formula = File.read('kontena.rb')
    new_stable_block = [
      "  stable do",
      "    url \"https://github.com/kontena/kontena.git\",",
      "        :tag => \"v#{ARGV[0]}\",",
      "        :revision => \"#{ARGV[1]}\"",
    ].join("\n")
    new_stable_block += File.read('../../homebrew-kontena/Formula/tmp/resources.rb')
    new_stable_block += "  end\n"

    stable_block = formula.scan(/^  \w+ do$.+?  end$/m).find { |blk| blk.start_with?('  stable do') }
    abort "Error parsing kontena.rb, 'stable do' block not found" if stable_block.nil?
    formula.sub(stable_block, new_stable_block)
    File.write('kontena.rb', formula)
EOB
  git checkout -b kontena-cli-$CLI_VERSION
  git add kontena.rb
  #git commit -m "kontena $CLI_VERSION"
  #git push fork kontena-cli-$CLI_VERSION

  # use Hub to submit a PR
  #install_hub || (echo "Failed to install hub"; exit 1)
  #hub pull-request -m "Automated PR from [travis-$TRAVIS_JOB_ID](https://travis-ci.org/kontena/kontena/jobs/$TRAVIS_JOB_ID) generated by [build/travis/deploy_homebrew.sh](https://github.com/kontena/kontena/blob/master/build/travis/deploy_homebrew.sh)"
}

CWD=$(pwd)
CLI_VERSION=$(ruby -e "print File.read('../../cli/VERSION').strip")
SHORT_HASH=$(git rev-parse --short HEAD)
LONG_HASH=$(git rev-parse HEAD)

echo "Creating a homebrew Formula for $CLI_VERSION @ $SHORT_HASH .."

#rm -rf brew 2> /dev/null
mkdir brew 2> /dev/null
cd brew || (echo "Can't create workdir"; exit 1)

clone_repositories || (echo "Failed to set up git workdirs"; exit 1)

if ruby -e "exit Gem::Version.new(ARGV.first).prerelease? ? 0 : 1" $CLI_VERSION; then
  prerelease
else
  stable
fi

cd $CWD

