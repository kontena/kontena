require_relative 'migration'
require_relative 'migration_proxy'
require_relative '../logging'
require_relative '../../helpers/wait_helper'

module Mongodb
  class Migrator
    include Logging
    include WaitHelper

    LOCK_NAME = 'mongodb_migrate'.freeze
    LOCK_TIMEOUT = (60 * 5)

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
      release_stale_lock
      lock_id = wait_until!("migration lock is available", timeout: LOCK_TIMEOUT, interval: 0.5) {
        DistributedLock.obtain_lock(LOCK_NAME)
      }
      migrate_without_lock
    ensure
      DistributedLock.release_lock(LOCK_NAME, lock_id) if lock_id
    end

    def release_stale_lock
      if DistributedLock.where(:name =>  LOCK_NAME, :created_at.lt => (LOCK_TIMEOUT * 2).seconds.ago).delete > 0
        info "released stale distributed lock"
      end
    end

    def migrate_without_lock
      migrations.each do |migration|
        unless already_migrated?(migration)
          info "migrating #{migration.name}"
          migration.migrate(:up)
          save_migration_version(migration)
          info "migrated #{migration.name}"
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
      rescue Mongo::Error::ConnectionFailure
        info "cannot connect to database, retrying in 1 second ..."
        sleep 1
        retry
      end
    end
  end
end
