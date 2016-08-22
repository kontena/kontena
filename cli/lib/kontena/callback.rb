class Kontena::Callback

  attr_reader :command

  def initialize(command)
    @command = command
  end

  # Register callback for command types it is supposed to run with.
  def self.command_types(*cmd_types)
    return @command_types if cmd_types.empty?

    # In case you call command_types([array, items, here]) instead of command_types(array, items, here)
    cmd_types = cmd_types.first if cmd_types.first.kind_of?(Array)

    unless cmd_types.first.kind_of?(Hash)
      cmd_types = Array(cmd_types).map{ |cmd_type| [cmd_type, :all] }.to_h
    end

    # Finally it should be normalized into a hash that looks like :cmd_class => :cmd_type, :app => :init, :grid => :all
    cmd_types.first.each do |cmd_class, cmd_type|
      Kontena::Callback.callbacks[cmd_class] ||= {}
      Kontena::Callback.callbacks[cmd_class][cmd_type] ||= []
      Kontena::Callback.callbacks[cmd_class][cmd_type] << self
    end
  end

  def self.callbacks
    @@callbacks ||= {}
  end

  def self.run_callbacks(cmd_type, state, obj)
    [cmd_type.last, :all].compact.uniq.each do |cmd|
      callbacks.fetch(cmd_type.first, {}).fetch(cmd, []).each do |klass|
        if klass.instance_methods.include?(state)
          cb = klass.new(obj)
          if cb.send(state).kind_of?(FalseClass)
            ENV["DEBUG"] && puts("Execution aborted by #{klass}")
            exit 1
          end
        end
      end
    end
  end
end

Dir[File.expand_path('../callbacks/**/*.rb', __FILE__)].sort_by{ |file| File.basename(file) }.each { |file| require file }
