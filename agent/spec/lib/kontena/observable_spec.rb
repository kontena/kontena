describe Kontena::Observable do
  let :observable_class do
    Class.new do
      include Celluloid
      include Kontena::Observable

      def crash
        fail
      end

      def spam_updates(enum, interval: false)
        enum.each do |value|
          sleep interval if interval
          update_observable value
        end
      end

      def ping

      end
    end
  end

  let :observer_class do
    Class.new do
      include Celluloid
      include Kontena::Observer

      attr_reader :state, :value, :first

      def initialize(observable, start: true)
        @observable = observable
        @first = nil
        @ordered = true
        self.start if start
      end

      def start
        @state = observe(@observable) do |value|
          @first ||= value
          if @value && @value > value
            warn "unordered value=#{value} after #{@value}"
            @ordered = false
          else
            debug "observed #{@value} -> #{value}"
          end
          @value = value
        end
      end

      def ping

      end

      def ready?
        !@value.nil?
      end
      def ordered?
        @ordered
      end

      def crash
        fail
      end
    end
  end

  subject { observable_class.new }

  let(:object) { double(:test) }

  it "rejects a nil update", :celluloid => true, :log_celluloid_actor_crashes => false do
    expect{subject.update_observable nil}.to raise_error(ArgumentError)
  end

  it "stops notifying any crashed observers", :celluloid => true, :log_celluloid_actor_crashes => false do
    observer = observer_class.new(subject)
    expect(subject.observers).to_not be_empty

    expect{observer.crash}.to raise_error(RuntimeError)

    # make sure the observer is really dead
    expect{observer.ping}.to raise_error(Celluloid::DeadActorError)
    expect(observer).to_not be_alive
    subject.ping

    subject.update_observable(object)
    expect(subject.observers).to be_empty
  end

  it "delivers updates in the right order", :celluloid => true do
    observer = observer_class.new(subject)

    update_count = 150

    subject.spam_updates(1..update_count, interval: false)

    expect(observer.value).to eq update_count
    expect(observer.ordered?).to be_truthy
  end

  it "handles concurrent observers", :celluloid => true do
    observer_count = 20
    update_count = 10

    # setup
    observers = observer_count.times.map {
      observer_class.new(subject, start: false)
    }

    observers.each do |obs|
      obs.async.start
    end

    # run updates sync while the observers are starting
    subject.spam_updates(1..update_count, interval: 0.001)

    # wait for observable to notify all observers
    subject.ping

    # wait for all observers to observe and update
    observers.each do |obs| obs.ping end
    observers.each do |obs| obs.ping end # and maybe a second round for the async update

    # all observers got the final value
    expect(observers.map{|obs| obs.value}).to eq [update_count] * observer_count

    # this is potentially racy, but it's important, or this spec doesn't test what it should
    expect(observers.map{|obs| obs.first}.max).to be > 1

    # also expect this...
    expect(observers.map{|obs| obs.ordered?}).to eq [true] * observer_count
  end

  context "For chained observables" do
    let :chaining_class do
      Class.new do
        include Celluloid
        include Kontena::Observer
        include Kontena::Observable

        def initialize(observable)
          @state = observe(observable) do |value|
            update_observable "chained: " + value
          end
        end

        def ping

        end
      end
    end

    it "propagates the observed value", :celluloid => true do
      chaining = chaining_class.new(subject)
      observer = observer_class.new(chaining)

      subject.update_observable "test"

      chaining.ping # wait for intermediate actor to handle update

      expect(observer).to be_ready
      expect(observer.value).to eq "chained: test"
    end
  end
end
