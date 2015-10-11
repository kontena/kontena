module Mongodb
  class MigrationProxy
    attr_accessor :version, :name, :filename
    delegate :migrate, to: :migration

    # @param [String] filename
    # @param [String] name
    # @param [Integer] version
    def initialize(filename, name, version)
      @filename = filename
      @name = name
      @version = version
    end

    private

    def migration
      @migration ||= load_migration
    end

    def load_migration
      load(filename)
      name.constantize
    end
  end
end
