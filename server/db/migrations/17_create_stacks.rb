class CreateStacks < Mongodb::Migration
  def self.up
    Stack.create_indexes
    StackRevision.create_indexes
    StackDeploy.create_indexes
    Grid.all.each do |grid|
      default_stack = grid.stacks.find_by(name: 'default')
      unless default_stack
        default_stack = Stack.create!(
          name: 'default',
          grid: grid
        )
      end
      grid.grid_services.where(stack_id: nil).each do |service|
        service.set(stack_id: default_stack.id)
      end
    end
  end
end
