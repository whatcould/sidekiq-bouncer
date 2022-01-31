# Mock
module RedisMock
end

# Mock
class WorkerMock
  def self.bouncer
    SidekiqBouncer::Bouncer.new(self)
  end
end

# Tests
describe SidekiqBouncer::Bouncer do

  before(:all) do
    SidekiqBouncer.configure do |config|
      config.redis = RedisMock
    end
  end

  let(:redis) { RedisMock }
  let(:worker_klass) { WorkerMock }
  let(:now) { 100 }

  before do
    # stubbing
    allow(subject).to receive(:now_i){ now }
    allow(redis).to receive(:set)
    allow(redis).to receive(:get)
    allow(redis).to receive(:del)
    allow(worker_klass).to receive(:perform_at)
  end

  # careful, the bouncer instance is generally cached on the worker model
  subject { WorkerMock.bouncer }

  describe '.new' do

    it 'raises an error when no worker class is passed' do
      expect { SidekiqBouncer::Bouncer.new() }.to raise_error(ArgumentError)
    end

    it 'raises an error when first argument is not a worker class' do
      expect { SidekiqBouncer::Bouncer.new(1) }.to raise_error(TypeError)
    end

    it 'has a default value for delay and delay_buffer' do
      expect(subject.delay).to eql(SidekiqBouncer::Bouncer::DELAY)
      expect(subject.delay_buffer).to eql(SidekiqBouncer::Bouncer::DELAY_BUFFER)
      expect(subject.only_params_at_index).to eql([])
    end

    it 'supports passing delay, delay_buffer and only_params_at_index params' do
      bouncer = SidekiqBouncer::Bouncer.new(WorkerMock, delay: 10, delay_buffer: 2, only_params_at_index: [1])
      expect(bouncer.delay).to eql(10)
      expect(bouncer.delay_buffer).to eql(2)
      expect(bouncer.only_params_at_index).to eql([1])
    end

  end

  describe '#debounce' do

    it 'sets delayed timestamp to Redis and calls perform_at with additional delay_buffer' do
      subject.debounce('test_param_1', 'test_param_2')

      expect(SidekiqBouncer.config.redis)
        .to have_received(:set)
        .with("#{worker_klass}:test_param_1,test_param_2", now + subject.delay)

      expect(worker_klass)
        .to have_received(:perform_at)
        .with(now + subject.delay + subject.delay_buffer, 'test_param_1', 'test_param_2')
    end

    it 'supports filtering params with @only_params_at_index' do
      subject.only_params_at_index = [1]

      subject.debounce('test_param_1', 'test_param_2')

      expect(SidekiqBouncer.config.redis)
        .to have_received(:set)
        .with("#{worker_klass}:test_param_2", now + subject.delay)

      expect(worker_klass)
        .to have_received(:perform_at)
        .with(now + subject.delay + subject.delay_buffer, 'test_param_1', 'test_param_2')
    end

  end

  describe '#let_in?' do

    it 'Redis receives params for #get' do
      subject.let_in?('test_param_1', 'test_param_2')

      expect(SidekiqBouncer.config.redis)
        .to have_received(:get)
        .with("#{worker_klass}:test_param_1,test_param_2")
    end

    it 'supports filtering Redis params for #get', :focus do
      subject.only_params_at_index = [1]
      subject.let_in?('test_param_1', 'test_param_2')

      expect(SidekiqBouncer.config.redis)
        .to have_received(:get)
        .with("#{worker_klass}:test_param_2")
    end

    context 'when debounce timestamp is in the past', :focus do
      before do
        allow(redis).to receive(:get).and_return(now - 10)
        allow(redis).to receive(:del)
      end

      it 'Redis receives params for #get and #del' do
        subject.let_in?('test_param_1', 'test_param_2')
  
        expect(SidekiqBouncer.config.redis)
          .to have_received(:del)
          .with("#{worker_klass}:test_param_1,test_param_2")
      end

      it 'returns true' do
        expect(subject.let_in?()).to eq(true)
      end
    end

    context 'when debounce timestamp is in the future' do
      before do
        allow(redis).to receive(:get).and_return(Time.now + 10)
      end

      # TODO check redis.del was not called

      it 'returns false' do
        expect(subject.let_in?()).to eq(false)
      end
    end

    context 'when debounce timestamp is not there' do
      before do
        allow(redis).to receive(:get).and_return(nil)
      end

      it 'returns false' do
        expect(subject.let_in?()).to eq(false)
      end
    end
  end

end
