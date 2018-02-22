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
    allow(subject).to receive(:already_cloud_enabled?).and_return(false)
    expect(Kontena).to receive(:run!).with(%w(cloud master add --current --force)).and_return(true)
    expect_any_instance_of(Kontena::Callbacks::InviteSelfAfterDeploy).to receive(:after).and_return(true)
    subject.run(['--force'])
  end

  it 'exits with error if master is already registered to use cloud' do
    expect(subject.cloud_client).to receive(:get).with('user/masters').and_return(
      'data' => [
        { 'attributes' => { 'client-id' => 'abc123', 'name' => 'testmaster' } },
        { 'attributes' => { 'client-id' => 'def234', 'name' => 'foo' } },
      ]
    )
    expect(subject.client).to receive(:get).with('config').and_return(
      'oauth2.client_id' => 'abc123'
    )
    expect{subject.run(['--force'])}.to exit_with_error.and output(/already registered.+?testmaster/).to_stderr
  end
end
