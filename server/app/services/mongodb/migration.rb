module Mongodb
  class Migration

    def self.migrate(direction)
      if direction == :up
        self.up
      end
    end

    def self.up
      raise NotImplementedError
    end

    def self.db
      Mongoid::Sessions.default
    end

    def self.info(msg)
      puts msg
    end
  end
end
