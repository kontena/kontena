require_relative '../../../lib/kontena/helpers/wait_helper'

describe Kontena::Observer, :celluloid => true do
  let :observable_class do
    TestObservable = Class.new do
      include Celluloid
      include Kontena::Observable

      def crash
        fail
      end

      def delay_update(value, delay: )
        after(delay) do
          update_observable value
        end
      end

      def spam_updates(values, delay:, duration: , interval: )
        until_time = Time.now + duration

        sleep delay

        for value in values
          break if Time.now >= until_time

          update_observable(value)

          sleep interval
        end
      end
    end
  end

  let :observer_class do
    TestObserver = Class.new do
      include Celluloid
      include Kontena::Observer

      attr_reader :state, :values

      def test_observe(*observables)
        @state = observe(*observables) do |*values|
          @values = values
        end
      end

      def ready?
        @state.ready?
      end

      def crash
        fail
      end
    end
  end

  subject { observer_class.new() }

  it "raises synchronously if given an invalid actor", :celluloid => true, :log_celluloid_actor_crashes => false do
    expect{subject.test_observe('foo')}.to raise_error(NoMethodError, /undefined method `add_observer' for "foo":String/)
  end

  context "For a single observable" do
    let(:observable) { observable_class.new }
    let(:object) { double(:test) }

    describe '#unwrap_observable' do
      it 'returns the wrapped object' do
        expect(described_class.unwrap_observable(observable)).to be_a TestObservable
        expect(described_class.unwrap_observable(observable).class).to eq TestObservable
      end
    end

    describe '#observe' do
      it "does not observe any value if not yet updated" do
        subject.test_observe(observable)

        expect(subject).to_not be_ready
      end

      it "immediately yields an updated value" do
        observable.update_observable object

        subject.test_observe(observable)

        expect(subject).to be_ready
        expect(subject.values).to eq [object]
      end

      it "later yields after updating value" do
        subject.test_observe(observable)

        expect(subject).to_not be_ready

        observable.update_observable object

        expect(subject).to be_ready
        expect(subject.values).to eq [object]
      end

      it "crashes if the observable does", :log_celluloid_actor_crashes => false do
        subject.test_observe(observable)

        expect{observable.crash}.to raise_error(RuntimeError)

        expect{subject.ready?}.to raise_error(Celluloid::DeadActorError)
      end
    end

    describe '#observe_sync' do
      it 'raises timeout if the observable is not ready' do
        expect{
          subject.observe(observable, timeout: 0.01)
        }.to raise_error(Timeout::Error, 'timeout after waiting 0.01s until: Observable<TestObservable>')
      end

      it 'immediately returns value if updated' do
        observable.update_observable(object)

        expect(subject.observe(observable)).to eq object

        observable.reset_observable
      end

      it 'blocks until observable' do
        observable.delay_update(object, delay: 0.5)

        # NOTE: the class must include the WaitHelper, so that it uses Celluloid#sleep
        #       if the wait_until! uses Kernel#sleep and blocks the actor thread,
        #       then this spec will fail, because the delayed update doesn't have a chance to run
        expect(subject.observe(observable, timeout: 1.0)).to eq object
      end

      it 'does not lose wait messages' do
        allow(subject.wrapped_object).to receive(:debug) do |msg|
          sleep 0.2
        end

        observable.async.spam_updates(1..1000, duration: 0.5, interval: 0.01, delay: 0.1)

        expect(subject.observe(observable, timeout: 1.0)).to be_a Integer
      end
    end

    context "Which later updates" do
      let(:object2) { double(:test2) }

      before do
        observable.update_observable object

        subject.test_observe(observable)

        expect(subject).to be_ready
        expect(subject.values).to eq [object]
      end

      it "yields with the updated value" do
        observable.update_observable object2

        expect(subject.values).to eq [object2]
      end

      it "does not yield after a reset" do
        observable.reset_observable

        expect(subject.values).to eq [object]
        expect(subject).to_not be_ready
      end
    end
  end

  context "For two observables" do
    let(:observable1) { observable_class.new }
    let(:observable2) { observable_class.new }

    let(:object1) { double(:test1) }
    let(:object2) { double(:test2) }
    let(:object3) { double(:test3) }

    it "yields with both values" do
      observable1.update_observable object1
      observable2.update_observable object2

      subject.test_observe(observable1, observable2)

      expect(subject).to be_ready
      expect(subject.values).to eq [object1, object2]
    end

    it "does not yield after a reset" do
      observable1.update_observable object1
      observable2.update_observable object2

      subject.test_observe(observable1, observable2)

      expect(subject.values).to eq [object1, object2]

      observable1.reset_observable
      observable2.update_observable object3

      expect(subject.values).to eq [object1, object2]
    end
  end

  context "For a supervised observer that observes a supervised actor by name" do
    let :supervised_observer_class do
      Class.new do
        include Celluloid
        include Kontena::Observer

        attr_reader :state, :values

        def initialize(actor_name)
          @state = observe(Celluloid::Actor[actor_name]) do |*values|
            @values = values
          end
        end

        def ready?
          @state.ready?
        end

        def crash
          fail
        end
      end
    end

    before :each do
      @observable_actor = Celluloid::Actor[:observable_test] = observable_class.new
      @observer_actor = Celluloid::Actor[:observer_test] = supervised_observer_class.new(:observable_test)

      expect(@observer_actor).to_not be_ready

      @observable_actor.update_observable 1

      expect(@observer_actor).to be_ready
      expect(@observer_actor.values).to eq [1]
    end

    it "crashing allows it to re-observe the existing value immediately after restarting", :log_celluloid_actor_crashes => false do
      expect{@observer_actor.crash}.to raise_error(RuntimeError)
      Kontena::Helpers::WaitHelper.wait_until! { @observer_actor.dead? }

      # simulate supervisor
      @observer_actor = Celluloid::Actor[:observer_test] = supervised_observer_class.new(:observable_test)

      expect(@observer_actor).to be_ready
      expect(@observer_actor.values).to eq [1]
    end

    it "restarts after the observable crashes and waits for it to update", :log_celluloid_actor_crashes => false do
      expect{@observable_actor.crash}.to raise_error(RuntimeError)
      Kontena::Helpers::WaitHelper.wait_until! { @observable_actor.dead? && @observer_actor.dead? }

      # simulate supervisor restart in the wrong order
      expect{supervised_observer_class.new(:observable_test)}.to raise_error(Celluloid::DeadActorError)
      @observable_actor = Celluloid::Actor[:observable_test] = observable_class.new
      @observer_actor = Celluloid::Actor[:observer_test] = supervised_observer_class.new(:observable_test)

      expect(@observer_actor).to_not be_ready

      @observable_actor.update_observable 2

      expect(@observer_actor).to be_ready
      expect(@observer_actor.values).to eq [2]
    end
  end

  context 'for a standalone Observable' do
    let :actor_class do
      ActorClass = Class.new do
        include Celluloid
      end
    end
    let :standaone_observable_class do
      StandaloneObservable = Class.new do
        include Kontena::Observable
      end
    end

    let(:actor) { actor_class.new }
    let(:observable) { standaone_observable_class.new }
    let(:value) { double() }

    describe '#unwrap_observable' do
      it 'returns the object' do
        expect(described_class.unwrap_observable(observable)).to be_a StandaloneObservable
        expect(described_class.unwrap_observable(observable).class).to eq StandaloneObservable
      end
    end

    it 'is observable' do
      observable
      actor.after(0.05) {
        observable.update_observable(value)
      }

      expect(subject.observe(observable, timeout: 1.0)).to eq value
    end
  end
end
