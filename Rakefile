
require 'colorize'
require 'dotenv'
Dotenv.load

VERSION = File.read('./VERSION').strip
UBUNTU_IMAGE = 'kontena-ubuntu-build'
UBUNTU_REPO = ENV['UBUNTU_REPO'] || 'ubuntu'
PKG_REV = ENV['PKG_REV'] || '1'

namespace :release do

  def headline(text)
    puts text.colorize(:yellow)
  end

  task :setup => [:bump_version] do
    %w(agent cli server).each do |dir|
      Dir.chdir(dir) do
        sh("bundle install")
      end
    end
  end

  task :bump_version do
    headline "Bumping version to #{VERSION}"
    %w(agent cli server).each do |dir|
      File.write("./#{dir}/VERSION", VERSION)
    end
  end

  task :setup_ubuntu do
    headline "Building Docker image for Ubuntu package builds ..."
    sh("docker build -t #{UBUNTU_IMAGE} -f build/Dockerfile.ubuntu .")
  end
  task :setup_cli_omnibus do
    headline "Setting up CLI omnibus..."
    Dir.chdir('cli') do
      sh("rake release:setup_omnibus")
    end
  end

  task :build => [
    :setup,
    :build_server,
    :build_agent
  ]

  task :build_server do
    headline "Starting to build kontena-server ..."
    Dir.chdir('server') do
      sh("bundle exec rake release:build_docker")
      sh("bundle exec rake release:build_docs")
    end
  end

  task :build_agent do
    headline "Starting to build kontena-agent ..."
    Dir.chdir('agent') do
      sh("bundle exec rake release:build_docker")
    end
  end

  task :build_cli do
    headline "Starting to build kontena-cli ..."
    Dir.chdir('cli') do
      sh("bundle exec rake release:build")
    end
  end

  task :build_cli_gem do
    headline "Starting to build kontena-cli gem ..."
    Dir.chdir('cli') do
      sh("gem build kontena-cli.gemspec")
    end
  end

  task :package_ubuntu => [
    :setup, :setup_ubuntu, :package_ubuntu_server, :package_ubuntu_agent
  ]

  task :package_ubuntu_cli do
    Dir.chdir('cli') do
      sh("rake release:build_omnibus")
    end
  end

  task :package_ubuntu_server do
    sh("docker run -it --rm -w /build/server -v #{Dir.pwd}/server/release:/build/server/release #{UBUNTU_IMAGE} rake release:build_ubuntu REV=#{PKG_REV}")
  end

  task :package_ubuntu_agent do
    sh("docker run -it --rm -w /build/agent -v #{Dir.pwd}/agent/release:/build/agent/release #{UBUNTU_IMAGE} rake release:build_ubuntu REV=#{PKG_REV}")
  end

  task :push => [
    :build,
    :push_server,
    :push_agent,
    :push_cli
  ]

  task :push_server do
    headline "Starting to push kontena/server ..."
    Dir.chdir('server') do
      sh("bundle exec rake release:push_docker")
      sh("bundle exec rake release:push_docs")
    end
  end

  task :push_agent do
    headline "Starting to push kontena/agent ..."
    Dir.chdir('agent') do
      sh("bundle exec rake release:push_docker")
    end
  end

  task :push_cli do
    headline "Starting to push kontena-cli ..."
    Dir.chdir('cli') do
      sh("bundle exec rake release:push")
    end
  end

  task :push_gem => [:build_cli_gem, :push_cli_gem]

  task :push_cli_gem do
    headline "Starting to push kontena-cli gem..."
    Dir.chdir('cli') do
      sh("gem push kontena-cli-#{VERSION}.gem")
    end
  end

  task :push_ubuntu => [
    :package_ubuntu,
    :push_ubuntu_server,
    :push_ubuntu_agent
  ]

  task :push_ubuntu_cli do
    Dir.chdir('cli') do
      sh("rake release:push_ubuntu REV=#{PKG_REV} REPO=#{UBUNTU_REPO}")
    end
  end

  task :push_ubuntu_server do
    Dir.chdir('server') do
      sh("bundle exec rake release:push_ubuntu REV=#{PKG_REV} REPO=#{UBUNTU_REPO}")
    end
  end

  task :push_ubuntu_agent do
    Dir.chdir('agent') do
      sh("bundle exec rake release:push_ubuntu REV=#{PKG_REV} REPO=#{UBUNTU_REPO}")
    end
  end
end
