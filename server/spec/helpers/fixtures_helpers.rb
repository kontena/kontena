module FixturesHelpers
  FIXTURES_PATH = File.dirname(__FILE__) + '/../fixtures/'

  def fixture(file)
    IO.read(FIXTURES_PATH+file)
  end
end