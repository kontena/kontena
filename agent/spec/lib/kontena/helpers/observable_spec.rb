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
  let :object2 do
    double(:test2)
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

      def wait
        sleep 0.1 until ready?
      end

      def crash
        fail
      end
    end
  end

  it "raises synchronously if given an invalid actor", :celluloid => true do
    expect{observer_class.new('foo')}.to raise_error(NoMethodError, /undefined method `add_observer' for "foo":String/)
  end

  it "rejects a nil update", :celluloid => true do
    expect{subject.update nil}.to raise_error(ArgumentError)
  end

  it "does not observe any value if not yet updated", :celluloid => true do
    observer = observer_class.new(subject)

    expect(observer).to_not be_ready
  end

  it "immediately observes an updated value", :celluloid => true do
    subject.update object

    observer = observer_class.new(subject)

    expect(observer).to be_ready
    expect(observer.values).to eq [object]
  end

  it "waits for an updated value", :celluloid => true do
    observer = observer_class.new(subject)

    wait_future = observer.future.wait

    subject.update object

    wait_future.value(1.0)

    expect(observer).to be_ready
    expect(observer.values).to eq [object]
  end

  context "For two observables", :celluloid => true do
    let(:subject1) { observable_class.new }
    let(:subject2) { observable_class.new }

    let(:observer) { observer_class.new(subject1, subject2) }

    it "yields with both values" do
      subject1.update object
      subject2.update object2

      expect(observer).to be_ready
      expect(observer.values).to eq [object, object2]
    end

    it "does not yield after a reset" do
      subject1.update 1
      subject2.update 2

      expect(observer.values).to eq [1, 2]

      subject1.reset
      subject2.update 3

      expect(observer.values).to eq [1, 2]
    end
  end

  it "does not yield after a reset", :celluloid => true do
    subject1 = observable_class.new
    subject2 = observable_class.new

    observer = observer_class.new(subject1, subject2)

    wait_future = observer.future.wait

    subject1.update object
    subject2.update object2

    wait_future.value(1.0)

    expect(observer).to be_ready
    expect(observer.values).to eq [object, object2]
  end

  it "crashes if the observable does", :celluloid => true do
    observer = observer_class.new(subject)

    expect{subject.crash}.to raise_error(RuntimeError)

    expect{observer.ready?}.to raise_error(Celluloid::DeadActorError)
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

      wait_future = observer.future.wait

      subject.update "test"

      wait_future.value(1.0)

      expect(observer).to be_ready
      expect(observer.values).to eq ["chained: test"]
    end
  end
end
