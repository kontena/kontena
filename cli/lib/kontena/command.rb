require 'clamp'

class Kontena::Command < Clamp::Command

  attr_accessor :arguments
  attr_reader :result
  attr_reader :exit_code


  def self.inherited(where)
    return if where.has_subcommands?
    return if where.callback_matcher

    name_parts = where.name.split('::')[-2, 2]

    unless name_parts.compact.empty?
      # 1: Remove trailing 'Command' from for example AuthCommand
      # 2: Convert the string from CamelCase to under_score
      # 3: Convert the string into a symbol
      #
      # In comes: ['ExternalRegistry', 'UseCommand']
      # Out goes: [:external_registry, :use]
      name_parts = name_parts.map { |np|
        np.gsub(/Command$/, '').
        gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
        gsub(/([a-z\d])([A-Z])/,'\1_\2').
        tr("-", "_").
        downcase.
        to_sym
      }
      where.callback_matcher(*name_parts)
    end

    # Run all #after_load callbacks for this command.
    [name_parts.last, :all].compact.uniq.each do |cmd_type|
      [name_parts.first, :all].compact.uniq.each do |cmd_class|
        if Kontena::Callback.callbacks.fetch(cmd_class, {}).fetch(cmd_type, nil)
          Kontena::Callback.callbacks[cmd_class][cmd_type].each do |cb|
            if cb.instance_methods.include?(:after_load)
              cb.new(where).after_load
            end
          end
        end
      end
    end
  end

  def self.callback_matcher(cmd_class = nil, cmd_type = nil)
    unless cmd_class
      if @command_class.nil?
        return nil
      else
        return [@command_class, @command_type]
      end
    end
    @command_class = cmd_class.to_sym
    @command_type = cmd_type.to_sym
    [@command_class, @command_type]
  end

  def run_callbacks(state)
    if self.class.respond_to?(:callback_matcher) && !self.class.callback_matcher.compact.empty?
      Kontena::Callback.run_callbacks(self.class.callback_matcher, state, self)
    end
  end

  # Overwrite Clamp's banner command. Calling banner multiple times 
  # will now add lines to the banner message instead of overwriting
  # the whole message. This is useful if callbacks add banner messages.
  #
  # @param [String] message
  def self.banner(msg, extra_feed = true)
    self.description = [self.description, extra_feed ? "\n#{msg}" : msg].compact.join("\n")
  end

  def self.requires_current_master
    banner "#{Kontena.pastel.green("Requires current master")}: This command requires that you have selected a current master using 'kontena master auth' or 'kontena master use'. You can also use the environment variable KONTENA_URL to specify the master address or KONTENA_MASTER=master_name to override the current_master setting."
    @requires_current_master = true
  end

  def self.requires_current_grid
    banner "#{Kontena.pastel.green("Requires current grid")}: This command requires that you have selected a grid as the current grid using 'kontena grid use' or by setting KONTENA_GRID environment variable."
    @requires_current_grid = true
  end

  def self.requires_current_account_token
    banner "#{Kontena.pastel.green("Requires account authentication")}: This command requires that you have authenticated to Kontena Cloud using 'kontena cloud auth'"
    @requires_current_account_token = true
  end


  def self.requires_current_master?
    @requires_current_master ||= false
  end

  def verify_current_master
    Kontena::Cli::Config.instance.require_current_master if self.class.requires_current_master?
  end

  def self.requires_current_grid?
    @requires_current_grid ||= false
  end

  def verify_current_grid
    Kontena::Cli::Config.instance.require_current_grid if self.class.requires_current_grid?
  end

  def self.requires_current_account_token?
    @requires_current_account_token ||= false
  end

  def verify_current_account_token
    retried ||= false
    Kontena::Cli::Config.instance.require_current_account_token if self.class.requires_current_account_token?
  end

  def self.requires_current_master_token
    @requires_current_master_token = true
  end

  def self.requires_current_master_token?
    @requires_current_master_token ||= false
  end

  def verify_current_master_token
    return nil unless self.class.requires_current_master_token?
    retried ||= false
    Kontena::Cli::Config.instance.require_current_master_token
  rescue Kontena::Cli::Config::TokenExpiredError
    success = Kontena::Client.new(
      Kontena::Cli::Config.instance.current_master,
      Kontena::Cli::Config.instance.current_master.token
    ).refresh_token
    if success && !retried
      retried = true
      retry
    else
      raise Kontena::Cli::Config::TokenExpiredError, "The access token has expired and refresh failed. Try authenticating again, use: kontena master auth"
    end
  end

  def help_requested?
    return true if @arguments.include?('--help')
    return true if @arguments.include?('-h')
    false
  end

  def run(arguments)
    ENV["DEBUG"] && puts("Running #{self} -- callback matcher = '#{self.class.callback_matcher.map(&:to_s).join(' ')}'")
    @arguments = arguments

    run_callbacks :before_parse unless help_requested?

    parse @arguments

    unless help_requested?
      verify_current_master
      verify_current_master_token
      verify_current_grid
      run_callbacks :before
    end

    begin
      @result = execute
      @exit_code = @result.kind_of?(FalseClass) ? 1 : 0
    rescue SystemExit => exc
      @result = exc.status == 0
      @exit_code = exc.status
    end
    run_callbacks :after unless help_requested?
    exit(@exit_code) if @exit_code.to_i > 0
    @result
  end
end

require_relative 'callback'
