require 'spec_helper'

describe 'plugin upgrade' do
  context "with older versions of the aws, digitalocean plugins installed" do
    before(:each) do
      run 'kontena plugin uninstall aws'
      run 'kontena plugin uninstall digitalocean'
      run! 'kontena plugin install --version 0.2.7 aws'
      run! 'kontena plugin install --version 0.2.5 digitalocean'
    end

    after(:each) do
      run 'kontena plugin uninstall aws'
      run 'kontena plugin uninstall digitalocean'
    end

    it 'upgrades all plugins' do
      k = run!('kontena plugin upgrade')
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
  end

  it 'does nothing if no updates' do
    run!('kontena plugin upgrade')
    k = run!('kontena plugin upgrade')
    expect(k.out).to match /Nothing upgraded/
  end
end
