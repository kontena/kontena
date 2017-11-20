require 'kontena_cli'

include Kontena::Cli::ShellSpinner

spinner 'Testing spinner' do
  sleep 0.1
end
