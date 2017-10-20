require 'spec_helper'

describe 'plugin update' do
  after(:each) do
    run('kontena plugin uninstall aws')
    run('kontena plugin uninstall digitalocean')
  end

  before(:each) do
    run('kontena plugin uninstall aws')
    run('kontena plugin uninstall digitalocean')
    run('kontena plugin install --version 0.2.7 aws')
    run('kontena plugin install --version 0.2.5 digitalocean')
  end

  it 'updates all plugins' do
    k = run('kontena plugin update')
    expect(k.code).to be_zero
    expect(k.out).to match(/aws/)
    expect(k.out).to match(/digitalocean/)
    k = run('kontena plugin list')
    lines = k.out.split(/[\r\n]/)
    lines.each do |line|
      plugin, version, _ = line.split(/\s+/, 3)
      if plugin == 'aws'
        expect(Gem::Version.new(version) > Gem::Version.new("0.2.7")).to be_truthy
      elsif plugin == 'digitalocean'
        expect(Gem::Version.new(version) > Gem::Version.new("0.2.5")).to be_truthy
      end
    end
  end

  it 'updates single plugin' do
    k = run('kontena plugin update digitalocean')
    expect(k.code).to be_zero
    expect(k.out).to match(/digitalocean/)
    k = run('kontena plugin list')
    lines = k.out.split(/[\r\n]/)
    lines.each do |line|
      plugin, version, _ = line.split(/\s+/, 3)
      if plugin == 'aws'
        expect(Gem::Version.new(version) == Gem::Version.new("0.2.7")).to be_truthy
      elsif plugin == 'digitalocean'
        expect(Gem::Version.new(version) > Gem::Version.new("0.2.5")).to be_truthy
      end
    end
  end

  it 'does nothing if no updates' do
    k = run('kontena plugin update')
    expect(k.code).to be_zero
    k = run('kontena plugin update')
    expect(k.code).to be_zero
    expect(k.out).to match /Nothing updated/
  end

  it 'exits with error if plugin not installed' do
    k = run('kontena plugin update nonexistent')
    expect(k.code).not_to be_zero
  end
end
