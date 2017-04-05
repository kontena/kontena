class Kontena::Callback

  attr_reader :command

  def initialize(command)
    @command = command
  end

  # Register callback for command types it is supposed to run with.
  def self.matches_commands(*commands)
    cmd_types = {}

    commands.each do |cmd|
      cmd_class, cmd_type = cmd.split(' ', 2)

      if cmd_class == '*'
        cmd_class = :all
      end

      if cmd_type.nil? || cmd_type == '*'
        cmd_type = :all
      else
        cmd_type = cmd_type.to_sym
      end
      cmd_types[cmd_class.to_sym] = cmd_type
    end

    # Finally it should be normalized into a hash that looks like :cmd_class => :cmd_type, :app => :init, :grid => :all
    cmd_types.each do |cmd_class, cmd_type|
      Kontena::Callback.callbacks[cmd_class] ||= {}
      Kontena::Callback.callbacks[cmd_class][cmd_type] ||= []
      Kontena::Callback.callbacks[cmd_class][cmd_type] << self
    end
  end

  def self.callbacks
    @@callbacks ||= {}
  end

  def self.run_callbacks(cmd_type, state, obj)
    [cmd_type.last, :all].compact.uniq.each do |cmdtype|
      [cmd_type.first, :all].compact.uniq.each do |cmdclass|
        callbacks.fetch(cmdclass, {}).fetch(cmdtype, []).each do |klass|
          if klass.instance_methods.include?(state)
            cb = klass.new(obj)
            if cb.send(state).kind_of?(FalseClass)
              ENV["DEBUG"] && $stderr.puts("Execution aborted by #{klass}")
              exit 1
            end
          end
        end
      end
    end
  end
end

Dir[File.expand_path('../callbacks/**/*.rb', __FILE__)].sort_by{ |file| File.basename(file) }.each { |file| require file }
