class Kontena::Plugin::Hello::WorldCommand < Kontena::Command

  def execute
    puts "hello world!"
  end
end
