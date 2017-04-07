module RequirementsHelper

  def self.included(base)
    base.extend ClassMethods
  end

  module ClassMethods
    def expect_to_require_current_master
      describe "prerequisites" do
        it "should require current master" do
          expect(described_class.requires_current_master?).to be_truthy
        end
      end
    end

    def expect_to_require_current_grid
      describe "prerequisites" do
        it "should require current grid" do
          expect(described_class.requires_current_grid?).to be_truthy
        end
      end
    end

    def expect_to_require_current_master_token
      describe "prerequisites" do
        it "should require current master token" do
          expect(described_class.requires_current_master_token?).to be_truthy
        end
      end
    end

    def mock_current_master
      before(:each) do
        allow(Kontena::Cli::Config.instance).to receive(:current_master).and_return(
          Kontena::Cli::Config::Server.new(
            url: 'https://test.example.com',
            name: 'master',
            token: Kontena::Cli::Config::Token.new(access_token: 'foo', account: :master, parent: 'master', parent_type: :master),
            grid: 'foogrid'
          )
        )
        allow(Kontena::Cli::Config.instance).to receive(:require_current_master).and_return(true)
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(File.join(Dir.home, '.kontena', 'config.json')).and_return(true)
        allow(File).to receive(:read).and_call_original
        allow(File).to receive(:read).with(File.join(Dir.home, '.kontena', 'config.json')).and_return("")
      end
    end
  end
end
