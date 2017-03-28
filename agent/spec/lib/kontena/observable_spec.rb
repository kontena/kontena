describe Kontena::Observable do
  let :observable_class do
    Class.new do
      include Celluloid
      include Kontena::Observable

      def crash
        fail
      end
    end
  end

  subject do
    observable_class.new
  end

  let :object do
    double(:test)
  end

  let :observer_class do
    Class.new do
      include Celluloid
      include Kontena::Observer

      attr_reader :state, :values

      def initialize(*observables)
        @state = observe(*observables) do |*values|
          @values = values
        end
      end

      def ready?
        !@values.nil?
      end

      def crash
        fail
      end
    end
  end

  it "rejects a nil update", :celluloid => true do
    expect{subject.update nil}.to raise_error(ArgumentError)
  end

  it "stops notifying any crashed observers", :celluloid => true do
    observer = observer_class.new(subject)
    expect(subject.observers).to_not be_empty

    expect{observer.crash}.to raise_error(RuntimeError)

    subject.update(object)
    expect(subject.observers).to be_empty
  end

  context "For chained observables" do
    let :chaining_class do
      Class.new do
        include Celluloid
        include Kontena::Observer
        include Kontena::Observable

        def initialize(observable)
          @state = observe(observable) do |value|
            update "chained: " + value
          end
        end
      end
    end

    it "propagates the observed value", :celluloid => true do
      chaining = chaining_class.new(subject)
      observer = observer_class.new(chaining)

      subject.update "test"

      expect(observer).to be_ready
      expect(observer.values).to eq ["chained: test"]
    end
  end
end
