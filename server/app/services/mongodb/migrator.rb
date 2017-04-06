require_relative 'migration'
require_relative 'migration_proxy'
require_relative '../logging'

module Mongodb
  class Migrator
    include Logging
    include DistributedLocks

    MigratorError = Class.new(StandardError)

    class DuplicateMigrationNameError < MigratorError
      def initialize(name)
        super("Multiple migrations have the name #{name}")
      end
    end

    class DuplicateMigrationVersionError < MigratorError
      def initialize(version)
        super("Multiple migrations have the version #{version}")
      end
    end

    class UnknownMigrationVersionError < MigratorError
      def initialize(version)
        super("No migration with version number #{version}")
      end
    end

    class IllegalMigrationNameError < MigratorError
      def initialize(name)
        super("Illegal name for migration file: #{name}\n\t(only lower case letters, numbers, and '_' allowed)")
      end
    end

    # @return [Array<String>]
    def load_migration_files
      Dir.glob('./db/migrations/*.rb')
    end

    # @return [Array<MigrationProxy>]
    def migrations
      files = load_migration_files
      migrations = []
      files.each do |file|
        version, name = file.scan(/([0-9]+)_([_a-z0-9]*).rb/).first

        raise IllegalMigrationNameError.new(file) unless version
        version = version.to_i

        if migrations.detect { |m| m.version == version }
          raise DuplicateMigrationVersionError.new(version)
        end

        if migrations.detect { |m| m.name == name.camelize }
          raise DuplicateMigrationNameError.new(name.camelize)
        end

        migrations << MigrationProxy.new(file, name.camelize, version)
      end

      migrations.sort_by(&:version)
    end

    def migrate
      ensure_indexes
      with_dlock('mongodb_migrate', 60) do
        migrate_without_lock
      end
    end

    def migrate_without_lock
      migrations.each do |migration|
        unless already_migrated?(migration)
          info "migrating #{migration.name}"
          migration.migrate(:up)
          save_migration_version(migration)
        end
      end
    end

    # @param [MigrationProxy] migration
    # @return [Boolean]
    def already_migrated?(migration)
      !SchemaMigration.find_by(version: migration.version).nil?
    end

    # @param [MigrationProxy] migration
    def save_migration_version(migration)
      unless SchemaMigration.find_by(version: migration.version)
        SchemaMigration.create(version: migration.version)
      end
    end

    def ensure_indexes
      begin
        DistributedLock.create_indexes
      rescue Moped::Errors::ConnectionFailure
        info "cannot connect to database, retrying in 1 second ..."
        sleep 1
        retry
      end
    end
  end
end
