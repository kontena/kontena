describe Stacks::SortHelper do
  let(:klass) {
    Class.new do
      include Stacks::SortHelper
    end
  }
  subject { klass.new }

  def check_services(sorted_services)
    ordered_services = []

    sorted_services.each do |service|
      service[:links].each do |link|
        expect(ordered_services).to include(link[:name]), "service #{service[:name]} with link #{link[:name]} was sorted after: #{ordered_services.join(' ')}"
      end if service[:links]
      ordered_services << service[:name]
    end
  end

  context "for a single service without links" do
    let(:services) { [
      {
        name: 'foo',
      },
    ]}

    it "is able to sort" do
      expect(subject.sort_services(services)).to eq services
    end
  end

  context "for two services hashes with a single link" do
    let(:services) { [
      {
        name: 'foo',
      },
      {
        name: 'bar',
        links: [
          {:name => 'foo', :alias => 'foo'}
        ]
      },
    ]}

    it "sorts them" do
      expect(subject.sort_services(services).map{|s| s[:name]}).to eq ['foo', 'bar']
    end

    it "sorts them from reverse order" do
      expect(subject.sort_services(services.reverse).map{|s| s[:name]}).to eq ['foo', 'bar']
    end
  end

  context "for two service objects with a single link" do
    let(:grid) { Grid.create!(name: 'test-grid') }
    let(:stack) { grid.stacks.find_by(name: Stack::NULL_STACK) }

    let(:service_a) { GridService.create!(grid: grid, stack: stack, name: 'a', image_name: 'redis:latest') }
    let(:service_b) { GridService.create!(grid: grid, stack: stack, name: 'b', image_name: 'redis:latest') }
    let(:services) { [service_a, service_b] }

    before do
      service_b.link_to(service_a)
      service_a.reload
    end

    it "sorts them" do
      expect(subject.sort_services(services).map{|s| s.name}).to eq ['a', 'b']
    end

    it "sorts them from reverse order" do
      expect(subject.sort_services(services.reverse).map{|s| s.name}).to eq ['a', 'b']
    end
  end

  context "for three services with a deep links" do
    let(:services) { [
      {
        name: 'foo',
      },
      {
        name: 'bar',
        links: [
          {:name => 'foo', :alias => 'foo'}
        ]
      },
      {
        name: 'asdf',
        links: [
          {:name => 'bar', :alias => 'bar'}
        ]
      },
    ]}

    it "is able to sort them" do
      expect(subject.sort_services(services).map{|s| s[:name]}).to eq ['foo', 'bar', 'asdf']
    end

    it "is able to sort them in reverse order" do
      expect(subject.sort_services(services.reverse).map{|s| s[:name]}).to eq ['foo', 'bar', 'asdf']
    end
  end

  context "for a complex set of linked services" do
    let(:services) { [
      {
        name: 'bar',
        links: [
          {:name => 'foo', :alias => 'api'}
        ]
      },
      {
        name: 'foo',
        links: [
          {:name => 'asdf', :alias => 'api'}
        ]
      },
      {
        name: 'asdf',
        links: [
          {:name => 'asdf1', :alias => 'asdf1'},
          {:name => 'asdf2', :alias => 'asdf2'},
          {:name => 'asdf3', :alias => 'asdf3'},
        ]
      },
      {
        name: 'asdf1',
      },
      {
        name: 'asdf2',
      },
      {
        name: 'asdf3',
      },
    ] }

    it "sorts them into the right order" do
      sorted_services = subject.sort_services(services)

      check_services(sorted_services)
    end
  end
end
