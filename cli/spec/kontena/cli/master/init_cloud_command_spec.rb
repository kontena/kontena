require "kontena/cli/master/init_cloud_command"

describe Kontena::Cli::Master::InitCloudCommand do

  include ClientHelpers
  include RequirementsHelper

  mock_current_master

  let(:cloud_client) { double(:cc) }

  before(:each) do
    allow(subject).to receive(:current_account).and_return('foo')
    allow(subject).to receive(:cloud_auth?).and_return(true)
  end

  describe '#execute' do
    expect_to_require_current_master
    expect_to_require_current_master_token
  end

  it 'runs the invite self after deploy callback' do
    expect(Kontena).to receive(:run).with(%w(cloud master add --current --force)).and_return(true)
    expect_any_instance_of(Kontena::Callbacks::InviteSelfAfterDeploy).to receive(:after).and_return(true)
    subject.run(['--force'])
  end
end
