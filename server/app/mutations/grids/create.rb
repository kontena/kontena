require 'celluloid'
require_relative '../../helpers/random_name_helper'

module Grids
  class Create < Mutations::Command
    include RandomNameHelper

    required do
      model :user
      string :name, nils: true, min_length: 3, matches: /^(\w|-)+$/
      integer :initial_size, default: 1, min: 1, max: 7
    end

    optional do
      string :token
      array :default_affinity do
        string
      end
      string :subnet
      string :supernet
    end

    def validate
      add_error(:user, :invalid, 'Operation not allowed') unless user.can_create?(Grid)
      existing = Grid.find_by(name: self.name)
      add_error(:grid, :already_exists, "Grid with name #{self.name} already exists") if existing

      if self.subnet
        @subnet = IPAddr.new(self.subnet) rescue add_error(:subnet, :invalid, $!.message)
      end

      if self.supernet
        @supernet = IPAddr.new(self.supernet) rescue add_error(:supernet, :invalid, $!.message)
      end
    end

    def execute
      self.name = generate_name if self.name.blank?
      grid = Grid.new(
        name: self.name,
        initial_size: self.initial_size,
        token: self.token,
        default_affinity: self.default_affinity.to_a
      )
      grid.subnet = self.subnet if self.subnet
      grid.supernet = self.supernet if self.supernet
      unless grid.save
        grid.errors.each do |key, message|
          add_error(key, :invalid, message)
        end
        return
      end
      user.grids << grid

      grid
    end
  end
end
