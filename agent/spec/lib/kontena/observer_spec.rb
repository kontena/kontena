require_relative '../../../lib/kontena/helpers/wait_helper'

class TestObserverActor
  include Celluloid
  include Kontena::Observer::Helper
  include Kontena::Logging

  def ping
    debug "ping"
  end

  def test_observe_async(*observables, **options)
    observe(*observables, **options) do |*values|
      @initial_values ||= values
      @observed_values = values
    end
  rescue Timeout::Error => exc
    abort exc
  end
  def observed?
    !@observed_values.nil?
  end
  def initial_values
    @initial_values
  end
  def observed_values
    @observed_values
  end

  def test_ordering(observable, rand_delay: nil)
    @observed_value = nil
    @observed_values = []
    @ordered = true
    @value = nil

    observe(observable) do |value|
      sleep(rand() * rand_delay) if rand_delay

      if @observed_value && @observed_value > value
        warn "unordered value=#{value} after #{@observed_value}"
        @ordered = false
      else
        debug "observed #{@observed_value} -> #{value}"
      end
      @observed_value = value
      @observed_values << value
    end
  end

  def observed_value
    @observed_value
  end
  def ordered?
    @ordered
  end

  def test_exclusive_observe(*observables, **options)
    exclusive {
      return observe(*observables, **options)
    }
  end

  def observe_until(observable, min)
    observe(observable) do |value|
      return value if value >= min
    end
  end

  def crash
    fail
  end
end

describe Kontena::Observer, :celluloid => true do
  subject { TestObserverActor.new() }

  it "raises synchronously if given an invalid actor", :celluloid => true, :log_celluloid_actor_crashes => false do
    expect{subject.test_observe_async('foo')}.to raise_error(NoMethodError, /undefined method `add_observer' for "foo":String/)
  end

  context "with an observable owned by a different actor" do
    let(:observable_actor) { TestObservableActor.new }
    let(:observable) { observable_actor.observable }
    let(:object) { double(:test) }

    describe '#observe_async' do
      it "does not observe any value if not yet updated" do
        subject.async.test_observe_async(observable)
        subject.ping

        expect(observable).to be_observed
        expect(subject).to_not be_observed
      end

      it "immediately yields an updated value" do
        observable_actor.update object

        subject.async.test_observe_async(observable)
        subject.ping

        expect(observable).to be_observed
        expect(subject).to be_observed
        expect(subject.observed_values).to eq [object]
      end

      it "later yields after updating value" do
        subject.async.test_observe_async(observable)
        subject.ping

        expect(observable).to be_observed
        expect(subject).to_not be_observed

        observable_actor.update object

        expect(subject).to be_observed
        expect(subject.observed_values).to eq [object]
      end

      it "crashes if the observable does", :log_celluloid_actor_crashes => true do
        subject.async.test_observe_async(observable)
        subject.ping

        expect(observable).to be_observed

        # The Celluloid::Call::Sync sends the RuntimeError response first, before triggering the actor crash
        # ping the crashed observable to make sure that it has a chance to send out the ExitEvent to linked actors
        expect{observable_actor.crash}.to raise_error(RuntimeError)
        expect{observable_actor.ping}.to raise_error(Celluloid::DeadActorError)

        Kontena::Observable.registry.wrapped_object # ping

        expect{subject.ping}.to raise_error(Celluloid::DeadActorError)
        expect(subject.alive?).to be_falsey
      end

      it "observes in order even if slow" do
        subject.async.test_ordering(observable, rand_delay: 0.1)
        subject.ping

        observable_actor.spam_updates(1..100, interval: 0.01, duration: 0.5)

        subject.ping

        #expect(subject.observed_values.last).to eq observable.observable_value
        expect(subject.ordered?).to be_truthy
      end

      it "stops observing on return" do
        observable_actor.async.spam_updates(1..10, delay: 0.01, interval: 0.01)

        expect(subject.observe_until(observable, 10)).to be >= 10

        observable_actor.update(11) # notice the dead observer

        expect(observable).to_not be_observed
      end

      it "fails with a timeout if the observable stops updating" do
        observable_actor.async.spam_updates(1..10, delay: 0.01, interval: 0.01)

        expect{subject.test_observe_async(observable, timeout: 0.1)}.to raise_error(Timeout::Error)

        expect(subject.observed_values.last).to eq 10
      end
    end

    describe '#observe_sync' do
      it 'raises timeout if the observable is not ready', :log_celluloid_actor_crashes => false do
        expect{
          subject.observe(observable, timeout: 0.01)
        }.to raise_error(Timeout::Error, 'observe timeout 0.01s: Kontena::Observable<TestObservableActor>?')
      end

      it 'immediately returns value if updated' do
        observable_actor.update(object)

        expect(subject.observe(observable)).to eq object

        observable_actor.reset
      end

      it 'blocks until observable without timeout' do
        observable_actor.delay_update(object, delay: 0.5)

        expect(subject.observe(observable)).to eq object
      end

      it 'blocks until observable with timeout' do
        observable_actor.delay_update(object, delay: 0.5)

        expect(subject.observe(observable, timeout: 1.0)).to eq object
      end

      it 'observes in non-persistent mode' do
        observable_actor.delay_update(object, delay: 0.1)

        expect(subject.observe(observable)).to eq object

        expect(observable).to_not be_observed
      end

      it 'does not lose wait messages' do
        allow(subject.wrapped_object).to receive(:debug) do |msg|
          sleep 0.2
        end

        observable_actor.async.spam_updates(1..1000, duration: 0.5, interval: 0.01, delay: 0.1)

        # XXX: this is likely to be a an old value, because the observable messages queue up,
        # and the first one resumes the waiting task
        expect(subject.observe(observable, timeout: 1.0)).to be_a Integer
      end

      describe 'in exclusive mode' do
        it 'waits until the observable updates' do
          observable_actor.delay_update(object, delay: 0.5)

          expect(subject.test_exclusive_observe(observable)).to eq object
        end

        it 'times out on one observable' do
          expect{
            subject.test_exclusive_observe(observable, timeout: 0.01)
          }.to raise_error(Timeout::Error, 'observe timeout 0.01s: Kontena::Observable<TestObservableActor>?')
        end

        it 'raises if the observable crashes' do
          observable_actor.async.crash(delay: 0.1)

          expect{
            subject.test_exclusive_observe(observable, timeout: 0.5)
          }.to raise_error(Kontena::Observer::Error)
        end

        describe 'with a timeout' do
          it 'raises if the observable crashes' do
            observable_actor.async.crash(delay: 0.1)

            expect{
              subject.test_exclusive_observe(observable, timeout: 1.0)
            }.to raise_error(Kontena::Observer::Error)
          end
        end
      end

      it 'raises if the observable crashes' do
        observable_actor.async.crash('test', delay: 0.1)

        expect{
          subject.observe(observable, timeout: 1.0)
        }.to raise_error(Kontena::Observer::Error, /: test/)
      end

      it 'does not terminate if the observable crashes after updating' do
        observable_actor.async.delay_update(object, delay: 0.1)

        expect(subject.test_exclusive_observe(observable)).to eq object

        expect{observable_actor.crash()}.to raise_error(RuntimeError)
        expect(subject.alive?).to be_truthy
        expect{subject.ping}.to_not raise_error # Celluloid::DeadActorError
      end

      context 'for an immediate observable' do
        before do
          observable_actor.update(object)
        end

        it 'observes in non-persistent mode' do
          expect(subject.observe(observable)).to eq object

          expect(observable).to_not be_observed
        end
      end
    end

    describe "with an observed value" do
      let(:object2) { double(:test2) }

      before do
        observable_actor.update object

        subject.async.test_observe_async(observable)
        subject.ping

        expect(subject).to be_observed
        expect(subject.observed_values).to eq [object]
      end

      it "yields with an updated value" do
        observable_actor.update object2

        expect(subject.observed_values).to eq [object2]
      end

      it "does not yield after a reset" do
        observable_actor.reset

        expect(subject.observed_values).to eq [object]
      end
    end

  end

  describe "observed from a non-celluloid thread", :celluloid => false do
    let(:observable) { Kontena::Observable.new }
    let(:object) { double(:object) }

    it "returns an existing value" do
      observable.update object

      expect(Kontena::Observer.observe(observable)).to eq object
    end

    it "waits for an observable value" do
      Thread.new {
        sleep 0.2
        observable.update object
      }

      expect(Kontena::Observer.observe(observable)).to eq object
    end

    it "yields with observed values" do
      Thread.new {
        sleep 0.1
        observable.update false
        sleep 0.1
        observable.update object
      }

      expect(Kontena::Observer.observe(observable) { |value| break value if value}).to eq object
    end
  end

  context "For two observables" do
    let(:observable_actor1) { TestObservableActor.new }
    let(:observable_actor2) { TestObservableActor.new }

    let(:observable1) { observable_actor1.observable }
    let(:observable2) { observable_actor2.observable }

    let(:object1) { double(:test1) }
    let(:object2) { double(:test2) }
    let(:object3) { double(:test3) }

    describe '#observe_async' do
      it "yields with both values" do
        observable_actor1.update object1
        observable_actor2.update object2

        subject.async.test_observe_async(observable1, observable2)
        subject.ping

        expect(subject).to be_observed
        expect(subject.observed_values).to eq [object1, object2]
      end

      it "does not yield after a reset" do
        observable_actor1.update object1
        observable_actor2.update object2

        subject.async.test_observe_async(observable1, observable2)
        subject.ping

        expect(subject.observed_values).to eq [object1, object2]

        observable_actor1.reset
        observable_actor2.update object3

        expect(subject.observed_values).to eq [object1, object2]
      end

      it "accepts update for first value while requesting second value" do
        # mock to simulate race condition
        expect(observable2).to receive(:add_observer) do |observer|
          observable_actor1.async.update object1 # XXX: can't suspend the observing task
          object2
        end

        subject.async.test_observe_async(observable1, observable2)

        subject.ping # wait for async observe setup to run
        observable_actor1.ping # wait for async update to finish
        subject.ping # wait for async observe to yield

        expect(subject.initial_values).to eq [object1, object2]
        expect(subject.observed_values).to eq [object1, object2]
      end
    end

    describe '#observe_sync' do
      it "returns both values if immediately available" do
        observable_actor1.update object1
        observable_actor2.update object2

        expect(subject.observe(observable1, observable2, timeout: 0.5)).to eq [object1, object2]
      end

      it "returns both values once available" do
        future = subject.future.observe(observable1, observable2, timeout: 0.5)

        observable_actor1.delay_update(object1, delay: 0.1)
        observable_actor2.delay_update(object2, delay: 0.1)

        expect(future.value).to eq [object1, object2]
      end

      it "waits for second value to become available" do
        observable_actor1.update object1

        future = subject.future.observe(observable1, observable2, timeout: 0.5)

        expect(future).to_not be_ready

        observable_actor2.update object2

        expect(future.value).to eq [object1, object2]
      end

      it "updates first value while waiting for second value" do
        observable_actor1.update(object1)

        future = subject.future.observe(observable1, observable2, timeout: 0.5)

        observable_actor1.delay_update(object3, delay: 0.1)
        observable_actor2.delay_update(object2, delay: 0.2)

        expect(future.value).to eq [object3, object2]
      end

      it "accepts update for first value while requesting second value" do
        expect(observable2).to receive(:add_observer) do |observer|
          observable_actor1.async.update object1 # XXX: can't suspend the observing task
          object2
        end

        expect(subject.observe(observable1, observable2)).to eq [object1, object2]
      end

      describe 'in exclusive mode' do
        it 'waits until both observables updates' do
          observable_actor1.delay_update(object1, delay: 0.5)
          observable_actor2.delay_update(object2, delay: 0.5)

          expect(subject.test_exclusive_observe(observable1, observable2)).to eq [object1, object2]
        end

        it 'times out even if one observable updates' do
          observable_actor1.update(0)
          observable_actor1.async.spam_updates((1..1000), interval: 0.01, duration: 0.5)

          expect{
            subject.test_exclusive_observe(observable1, observable2, timeout: 0.1)
          }.to raise_error(Timeout::Error, /observe timeout 0.\d+s: Kontena::Observable<TestObservableActor>, Kontena::Observable<TestObservableActor>\?/)
        end
      end
    end
  end

  describe "standalone" do
    context "with a single observable and observer" do
      let :actor_class do
        Class.new do
          include Celluloid

          def initialize
            @observers = {}
          end

          def test_observe_sync(*observables, **options)
            Kontena::Observer.observe(*observables, **options)
          end
        end
      end

      subject { actor_class.new }

      let(:observable_actor) { TestObservableActor.new }
      let(:observable) { observable_actor.observable }
      let(:object) { double(:test) }

      describe '#observe_async' do
        # XXX: this is probably not a good idea?
      end

      describe '#observe_sync' do
        it "observes updates" do
          observable_actor.delay_update(object, delay: 0.1)

          expect(subject.test_observe_sync(observable, timeout: 0.5)).to eq object
        end

        context 'with multiple observers' do
          it "observes each update" do
            observable_actor.delay_update(object, delay: 0.1)

            futures = (1..4).map{|id| subject.future.test_observe_sync(observable) }

            expect(futures.map{|f| f.value}).to eq [object, object, object, object]
          end
        end
      end
    end
  end

  context "For a supervised observer that observes a supervised actor by name" do
    let :supervised_observer_class do
      Class.new do
        include Celluloid
        include Kontena::Observer::Helper

        attr_reader :state, :values

        def start(actor_name)
          observe(Celluloid::Actor[actor_name].observable) do |*values|
            @values = values
          end
        end

        def ping

        end

        def ready?
          !!@values
        end

        def crash
          fail
        end
      end
    end

    before :each do
      @observable_actor = Celluloid::Actor[:observable_test] = TestObservableActor.new
      @observer_actor = Celluloid::Actor[:observer_test] = supervised_observer_class.new
      @observer_actor.async.start(:observable_test)
      @observer_actor.ping

      expect(@observer_actor).to_not be_ready

      @observable_actor.update 1

      expect(@observer_actor.values).to eq [1]
    end

    it "crashing allows it to re-observe the existing value immediately after restarting", :log_celluloid_actor_crashes => false do
      expect{@observer_actor.crash}.to raise_error(RuntimeError)
      Kontena::Helpers::WaitHelper.wait_until! { @observer_actor.dead? }

      # simulate supervisor
      @observer_actor = Celluloid::Actor[:observer_test] = supervised_observer_class.new
      @observer_actor.async.start(:observable_test)
      @observer_actor.ping; @observable_actor.ping # wait for the Actor[...].observable
      @observer_actor.ping # wait for the observe()

      expect(@observer_actor.values).to eq [1]
    end

    it "restarts after the observable crashes and waits for it to update", :log_celluloid_actor_crashes => false do
      expect{@observable_actor.crash}.to raise_error(RuntimeError)
      Kontena::Helpers::WaitHelper.wait_until!(timeout: 0.5) { @observable_actor.dead? && @observer_actor.dead? }

      # simulate supervisor restart in the wrong order
      @observer_actor = supervised_observer_class.new
      @observer_actor.async.start(:observable_test)
      expect{@observer_actor.ping}.to raise_error(Celluloid::DeadActorError)

      @observable_actor = Celluloid::Actor[:observable_test] = TestObservableActor.new

      @observer_actor = Celluloid::Actor[:observer_test] = supervised_observer_class.new
      @observer_actor.async.start(:observable_test)
      @observer_actor.ping

      expect(@observer_actor).to_not be_ready

      @observable_actor.update 2

      expect(@observer_actor.values).to eq [2]
    end
  end
end
