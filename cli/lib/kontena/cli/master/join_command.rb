module Kontena::Cli::Master
  class JoinCommand < Kontena::Command
    parameter "URL", "Kontena Master URL or name"
    parameter "INVITE_CODE", "Invitation code"

    option ['-n', '--name'], '[NAME]', 'Set server name'
    option ['-r', '--remote'], :flag, 'Do not try to open a browser'
    option ['-v', '--verbose'], :flag, 'Increase output verbosity'

    def execute
      params = []
      params << "--join #{self.invite_code.shellescape}"
      params << "--remote" if self.remote?
      params << "--name #{self.name.shellescape}" if self.name
      params << "--verbose" if self.verbose?

      cmd = ['master', 'login'] + params
      cmd << url
      Kontena.run!(cmd)
    end
  end
end
