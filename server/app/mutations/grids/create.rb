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

    def validate
      add_error(:user, :invalid, 'Operation not allowed') unless user.can_create?(Grid)
    end

    def execute
      self.name = generate_name if self.name.blank?
      grid = Grid.new(
        name: self.name,
        initial_size: self.initial_size
      )
      unless grid.save
        grid.errors.each do |key, message|
          add_error(key, :invalid, message)
        end
        return
      else
        initialize_subnet(grid)
      end
      user.grids << grid

      grid
    end

    def initialize_subnet(grid)
      Celluloid::Future.new{
        overlay_allocator = Docker::OverlayCidrAllocator.new(grid)
        overlay_allocator.initialize_grid_subnet
      }
    end
  end
end
