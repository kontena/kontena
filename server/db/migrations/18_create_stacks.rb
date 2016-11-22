class CreateStacks < Mongodb::Migration
  def self.up
    Stack.create_indexes
    Grid.all.each do |grid|
      if default_stack = grid.stacks.find_by(name: 'default')
        grid.grid_services.where(stack_id: default_stack.id).each do |service|
          service.set(stack_id: nil)
        end

        default_stack.remove
      end
    end
  end
end
