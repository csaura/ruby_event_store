require 'SecureRandom'

RSpec.shared_examples 'event_repository' do |repository_class|
  TestDomainEvent = Class.new(RubyEventStore::Event)
  let(:stream)          { SecureRandom.uuid }
  let(:random_stream)   { SecureRandom.uuid }
  let(:event)           { TestDomainEvent.new }
  let(:expected_event)  { {event_type: 'TestDomainEvent', data: {}} }
  subject(:repository)  { repository_class.new }

  it 'just created is empty' do
    expect(repository.read_all_streams_forward(:head, 1)).to be_empty
  end

  it 'created event is stored in given stream' do
    created = repository.create(event, stream)
    expect(created).to be_event(expected_event)
    expect(repository.read_all_streams_forward(:head, 1).first).to be_event(expected_event)
    expect(repository.read_stream_events_forward(stream).first).to be_event(expected_event)
    expect(repository.read_stream_events_forward(random_stream)).to be_empty
  end

  it 'does not have deleted streams' do
    repository.create(event, stream)
    expect(repository.read_stream_events_forward(stream).count).to eq 1

    repository.delete_stream(stream)
    expect(repository.read_stream_events_forward(stream)).to be_empty
  end

  it 'has or has not domain event' do
    event_id = SecureRandom.uuid
    event = TestDomainEvent.new(event_id: event_id)
    repository.create(event, stream)

    expect(repository.has_event?(event_id)).to be_truthy
    expect(repository.has_event?(SecureRandom.uuid)).to be_falsey
  end

  it 'knows last event in stream' do
    event_1_id = SecureRandom.uuid
    repository.create(TestDomainEvent.new(event_id: event_1_id), stream)
    event_2_id = SecureRandom.uuid
    repository.create(TestDomainEvent.new(event_id: event_2_id), stream)

    expect(repository.last_stream_event(stream).event_id).to eq(event_2_id)
    expect(repository.last_stream_event(random_stream)).to be_nil
  end

  it 'reads batch of events from stream forward & backward' do
    event_ids = (1..10).to_a.map(&:to_s)
    event_ids.each do |id|
      repository.create(TestDomainEvent.new(event_id: id), stream)
    end

    expect(repository.read_events_forward(stream, :head, 3).map(&:event_id)).to eq ['1','2','3']
    expect(repository.read_events_forward(stream, :head, 100).map(&:event_id)).to eq event_ids
    expect(repository.read_events_forward(stream, '5', 4).map(&:event_id)).to eq ['6','7','8','9']
    expect(repository.read_events_forward(stream, '5', 100).map(&:event_id)).to eq ['6','7','8','9','10']

    expect(repository.read_events_backward(stream, :head, 3).map(&:event_id)).to eq ['10','9','8']
    expect(repository.read_events_backward(stream, :head, 100).map(&:event_id)).to eq event_ids.reverse
    expect(repository.read_events_backward(stream, '5', 4).map(&:event_id)).to eq ['4','3','2','1']
    expect(repository.read_events_backward(stream, '5', 100).map(&:event_id)).to eq ['4','3','2','1']
  end


  it 'reads all stream events forward & backward' do
    repository.create(TestDomainEvent.new(event_id: '1'), stream)
    repository.create(TestDomainEvent.new(event_id: '2'), random_stream)
    repository.create(TestDomainEvent.new(event_id: '3'), stream)
    repository.create(TestDomainEvent.new(event_id: '4'), random_stream)
    repository.create(TestDomainEvent.new(event_id: '5'), random_stream)

    expect(repository.read_stream_events_forward(stream).map(&:event_id)).to eq ['1','3']
    expect(repository.read_stream_events_backward(stream).map(&:event_id)).to eq ['3','1']
  end

  it 'reads batch of events from all streams forward & backward' do
    event_ids = (1..10).to_a.map(&:to_s)
    event_ids.each do |id|
      repository.create(TestDomainEvent.new(event_id: id), SecureRandom.uuid)
    end

    expect(repository.read_all_streams_forward(:head, 3).map(&:event_id)).to eq ['1','2','3']
    expect(repository.read_all_streams_forward(:head, 100).map(&:event_id)).to eq event_ids
    expect(repository.read_all_streams_forward('5', 4).map(&:event_id)).to eq ['6','7','8','9']
    expect(repository.read_all_streams_forward('5', 100).map(&:event_id)).to eq ['6','7','8','9','10']

    expect(repository.read_all_streams_backward(:head, 3).map(&:event_id)).to eq ['10','9','8']
    expect(repository.read_all_streams_backward(:head, 100).map(&:event_id)).to eq event_ids.reverse
    expect(repository.read_all_streams_backward('5', 4).map(&:event_id)).to eq ['4','3','2','1']
    expect(repository.read_all_streams_backward('5', 100).map(&:event_id)).to eq ['4','3','2','1']
  end

end
