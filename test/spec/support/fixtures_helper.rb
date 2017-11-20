module FixturesHelper
  FIXTURES_PATH = File.dirname(__FILE__) + '/../fixtures/'

  def fixture_path(file)
    File.expand_path(FIXTURES_PATH + file)
  end
  def fixture(file)
    IO.read(fixture_path(file))
  end
end
