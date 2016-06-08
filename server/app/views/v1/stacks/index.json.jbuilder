json.stacks @stacks do |stack|
  json.partial! 'app/views/v1/stacks/stack', stack: stack
end