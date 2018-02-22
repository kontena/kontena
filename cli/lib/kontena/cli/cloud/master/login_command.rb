module Kontena::Cli::Cloud::Master
  class LoginCommand < Kontena::Command

    include Kontena::Cli::Common

    parameter "[NAME]", "Kontena Master name. Leave empty to select interactively."

    option ['-r', '--[no-]remote'], :flag, 'Login using a browser on another device', default: Kontena.browserless?
    option ['-f', '--force'], :flag, 'Force reauthentication'

    callback_matcher 'cloud-master', 'login'

    requires_current_account_token

    def get_potential_masters
      @masters ||= spinner "Retrieving a list of Kontena Masters registered to Kontena Cloud" do
        cloud_client.get('user/masters')['data'].reject { |m| m['attributes']['url'].nil? || m['attributes']['redirect-uri'].nil? }
      end
    end

    def execute
      masters = get_potential_masters
      if name.nil?
        master_id = Kontena.prompt.select("Select Kontena Master") do |menu|
          masters.each do |master|
            menu.choice "#{master['attributes']['name']} (#{master['attributes']['url']})", master['id']
          end
        end
      else
        master_id = masters.find { |master| master['attributes']['name'] == name || master['id'] == name }
      end

      if master_id
        master = masters.find { |m| m['id'] == master_id }
        login_args = ['master', 'login', '--name', master['attributes']['name']]
        login_args << '--force' if force?
        login_args << '--remote' if remote?
        login_args << master['attributes']['url']
        Kontena.run(login_args)
      else
        exit_with_error "Master not #{name.nil? ? "selected" : "found"}"
      end
    end
  end
end
