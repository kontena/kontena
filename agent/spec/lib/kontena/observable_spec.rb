class TestObservableActor
  include Celluloid

  attr_accessor :observable

  def initialize
    @observable = Kontena::Observable.register
  end

  def ping

  end

  def crash(msg = nil, delay: nil)
    sleep delay if delay
    if msg
      fail msg
    else
      fail
    end
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

describe Kontena::Observable do
  let(:value) { double(:value) }

  describe '#update' do
    it "rejects a nil update" do
      expect{subject.update nil}.to raise_error(ArgumentError)
    end
  end

  context 'when initialized' do
    it 'is not observable?' do
      expect(subject).to_not be_observable
    end

    it 'is not crashed?' do
      expect(subject).to_not be_crashed
    end

    describe '#get' do
      it 'returns nil' do
        expect(subject.get).to be nil
      end
    end
  end

  context 'when updated' do
    before do
      subject.update value
    end

    it 'is observable?' do
      expect(subject).to be_observable
    end

    it 'is not crashed?' do
      expect(subject).to_not be_crashed
    end

    describe '#get' do
      it 'returns the value' do
        expect(subject.get).to eq value
      end
    end

    context 'when reset' do
      before do
        subject.reset
      end

      it 'is not observable?' do
        expect(subject).to_not be_observable
      end

      it 'is not crashed?' do
        expect(subject).to_not be_crashed
      end

      describe '#get' do
        it 'returns nil' do
          expect(subject.get).to be nil
        end
      end
    end
  end

  context 'when crashed' do
    before do
      subject.crash RuntimeError.new
    end

    it 'is observable?' do
      expect(subject).to be_observable
    end

    it 'is crashed?' do
      expect(subject).to be_crashed
    end

    describe '#update' do
      it "rejects any update" do
        expect{subject.update nil}.to raise_error(RuntimeError)
      end
    end
  end

  context 'registered by an Actor', :celluloid => true do
    let(:registry) { Kontena::Observable.registry }
    let(:observable_actor) { TestObservableActor.new }
    subject { observable_actor.observable }
    let(:observer_actor) { TestObserverActor.new }

    it 'is observable after updating' do
      observable_actor.update(value)

      expect(observer_actor.observe(subject, timeout: 0.0)).to eq value
    end

    it 'is observable before updating' do
      observable_actor.delay_update(value, delay: 0.05)

      expect(observer_actor.observe(subject, timeout: 1.0)).to eq value
    end

    it "propagates crashes to observers and unregisters after crashing" do
      subject

      expect(registry.registered? subject).to be_truthy

      observable_actor.async.crash('test', delay: 0.1)

      expect{observer_actor.observe(subject)}.to raise_error(Kontena::Observer::Error, 'RuntimeError@Kontena::Observable<TestObservableActor>: test')

      expect(registry.registered? subject).to be_falsey
    end

    it "stops notifying any crashed observers", :log_celluloid_actor_crashes => false do
      observer_actor.test_observe_async(subject)

      expect(subject).to be_observed

      expect{observer_actor.crash}.to raise_error(RuntimeError)

      # make sure the observer is really dead
      expect{observer_actor.ping}.to raise_error(Celluloid::DeadActorError)
      expect(observer_actor).to_not be_alive

      subject.update(value)
      expect(subject).to_not be_observed
    end

    it "delivers updates in the right order" do
      observer_actor.test_ordering(subject)

      update_count = 150

      observable_actor.spam_updates(1..update_count, interval: false)

      expect(observer_actor.observed_values.last).to eq update_count
      expect(observer_actor.ordered?).to be_truthy
    end

    it "handles concurrent observers" do
      observer_count = 20
      update_count = 10

      # setup
      observer_actors = observer_count.times.map {
        TestObserverActor.new
      }

      observer_actors.each do |actor|
        actor.async.test_ordering(subject)
      end

      # run updates sync while the observers are starting
      observable_actor.spam_updates(1..update_count, interval: 0.001)

      # wait for actor to notify all observers
      observable_actor.ping

      # wait for all observers to observe and update
      observer_actors.each do |actor|
        actor.ping
      end

      # all observers got the final value
      expect(observer_actors.map{|actor| actor.observed_values.last}).to eq [update_count] * observer_count

      # also expect this...
      expect(observer_actors.map{|actor| actor.ordered?}).to eq [true] * observer_count

      # some observers only observed after the first update
      # this is potentially racy, but it's important, or this spec doesn't test what it should
      expect(observer_actors.map{|actor| actor.observed_values.first}.max).to be > 1
    end

    describe "propagating observed updates" do
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
