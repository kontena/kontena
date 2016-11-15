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
      string :subnet
      string :supernet
    end

    def validate
      add_error(:user, :invalid, 'Operation not allowed') unless user.can_create?(Grid)
      existing = Grid.find_by(name: self.name)
      add_error(:grid, :already_exists, "Grid with name #{self.name} already exists") if existing
      IPAddr.new(self.subnet) rescue add_error(:subnet, :invalid, $!.message) if self.subnet
      IPAddr.new(self.supernet) rescue add_error(:supernet, :invalid, $!.message) if self.supernet
    end

    def execute
      self.name = generate_name if self.name.blank?
      grid = Grid.new(
        name: self.name,
        initial_size: self.initial_size,
        token: self.token,
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
