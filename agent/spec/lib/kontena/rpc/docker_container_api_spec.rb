
describe Kontena::Rpc::DockerContainerApi do

  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }

  let(:image) { double(:image, info: {
    'Config' => {
      'Cmd' => ["nginx", "-g", "daemon off;"]
    }
  })}
end
