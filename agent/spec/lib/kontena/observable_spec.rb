class TestObservableActor
  include Celluloid

  attr_accessor :observable

  def initialize
    @observable = Kontena::Observable.new
  end

  def ping

  end

  def crash(delay: nil)
    sleep delay if delay
    fail
  end

  def update(value)
    @observable.update(value)
  end

  def reset
    @observable.reset
  end

  def delay_update(value, delay: )
    after(delay) do
      @observable.update(value)
    end
  end

  def spam_updates(values, delay: nil, duration: nil, interval: nil)
    deadline = Time.now + duration if duration

    sleep delay if delay

    for value in values
      break if deadline && Time.now >= deadline

      @observable.update(value)

      sleep interval if interval
    end
  end
end

class TestObservableStandalone < Kontena::Observable

end

describe Kontena::Observable, :celluloid => true do
  let(:observable_actor) { TestObservableActor.new }
  subject { observable_actor.observable }
  let(:observer) { TestObserverActor.new }
  let(:object) { double(:test) }

  describe '#update_observable' do
    it "rejects a nil update", :log_celluloid_actor_crashes => false do
      expect{subject.update nil}.to raise_error(ArgumentError)
    end
  end

  context 'when initialized' do
    it 'is not observable?' do
      expect(subject).to_not be_observable
    end

    describe '#value' do
      it 'returns nil' do
        expect(subject.get).to be nil
      end
    end
  end

  context 'when updated' do
    before do
      subject.update object
    end

    it 'is observable?' do
      expect(subject).to be_observable
    end

    describe '#observable_value' do
      it 'returns the value' do
        expect(subject.get).to eq object
      end
    end

    context 'when reset' do
      before do
        subject.reset
      end

      it 'is not observable?' do
        expect(subject).to_not be_observable
      end

      describe '#observable_value' do
        it 'returns nil' do
          expect(subject.get).to be nil
        end
      end
    end
  end

  it "stops notifying any crashed observers", :log_celluloid_actor_crashes => false do
    observer.test_observe_async(subject)

    expect(subject).to be_observed

    expect{observer.crash}.to raise_error(RuntimeError)

    # make sure the observer is really dead
    expect{observer.ping}.to raise_error(Celluloid::DeadActorError)
    expect(observer).to_not be_alive

    subject.update(object)
    expect(subject).to_not be_observed
  end

  it "delivers updates in the right order" do
    observer.test_ordering(subject)

    update_count = 150

    observable_actor.spam_updates(1..update_count, interval: false)

    expect(observer.observed_values.last).to eq update_count
    expect(observer.ordered?).to be_truthy
  end

  it "handles concurrent observers" do
    observer_count = 20
    update_count = 10

    # setup
    observers = observer_count.times.map {
      TestObserverActor.new
    }

    observers.each do |observer|
      observer.async.test_ordering(subject)
    end

    # run updates sync while the observers are starting
    observable_actor.spam_updates(1..update_count, interval: 0.001)

    # wait for actor to notify all observers
    observable_actor.ping

    # wait for all observers to observe and update
    observers.each do |obs| obs.ping end
    observers.each do |obs| obs.ping end # and maybe a second round for the async update

    # all observers got the final value
    expect(observers.map{|obs| obs.observed_values.last}).to eq [update_count] * observer_count

    # also expect this...
    expect(observers.map{|obs| obs.ordered?}).to eq [true] * observer_count
    
    # some observers only observed after the first update
    # this is potentially racy, but it's important, or this spec doesn't test what it should
    expect(observers.map{|obs| obs.observed_values.first}.max).to be > 1
  end

  context 'for a standalone Observable' do
    let(:value) { double() }

    it 'is observable' do
      observable_actor.delay_update(value, delay: 0.05)

      expect(observer.observe(subject, timeout: 1.0)).to eq value
    end
  end

  context "For chained observables" do
    let :chaining_class do
      Class.new do
        include Celluloid
        include Kontena::Observer

        attr_reader :observable

        def initialize
          @observable = Kontena::Observable.new
        end

        def test_observe_chain(observable)
          @observe_state = observe(observable) do |value|
            @observable.update "chained: " + value
          end
        end

        def ping

        end
      end
    end

    let(:chaining_actor) { chaining_class.new }
    let(:observer_actor) { TestObserverActor.new }

    describe '#observe => #update_observable' do
      it "propagates the observed value" do
        chaining_actor.test_observe_chain(subject)
        observer_actor.test_observe_async(chaining_actor.observable)

        observable_actor.update "test"

        chaining_actor.ping # wait for intermediate actor to handle update

        expect(observer_actor).to be_observe_ready
        expect(observer_actor.observed_values).to eq ["chained: test"]
      end
    end
  end
end
