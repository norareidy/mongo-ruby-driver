require 'spec_helper'

describe Mongo::Server::Monitor do

  let(:address) do
    Mongo::Address.new('127.0.0.1:27017')
  end

  describe '#scan!' do

    context 'when the ismaster command succeeds' do

      let(:server) do
        Mongo::Server.new(address, Mongo::Event::Listeners.new)
      end

      let(:monitor) do
        described_class.new(server.description)
      end

      before do
        monitor.scan!
      end

      it 'updates the server description' do
        expect(server.description).to be_standalone
      end
    end

    context 'when the ismaster command fails' do

      context 'when no server is running on the address' do

        let(:bad_address) do
          Mongo::Address.new('127.0.0.1:27050')
        end

        let(:server) do
          Mongo::Server.new(bad_address, Mongo::Event::Listeners.new)
        end

        let(:monitor) do
          described_class.new(server.description)
        end

        before do
          monitor.scan!
        end

        it 'keeps the server unknown' do
          expect(server).to be_unknown
        end
      end

      context 'when the socket gets an exception' do

        let(:bad_address) do
          Mongo::Address.new('127.0.0.1:27017')
        end

        let(:server) do
          Mongo::Server.new(bad_address, Mongo::Event::Listeners.new)
        end

        let(:monitor) do
          described_class.new(server.description)
        end

        let(:socket) do
          monitor.connection.connect!
          monitor.connection.__send__(:socket)
        end

        before do
          expect(socket).to receive(:write).and_raise(SocketError)
          monitor.scan!
        end

        it 'keeps the server unknown' do
          expect(server).to be_unknown
        end

        it 'disconnects the connection' do
          expect(monitor.connection.send(:socket)).to be_nil
        end
      end
    end
  end

  describe '#heartbeat_frequency' do

    let(:server) do
      Mongo::Server.new(address, Mongo::Event::Listeners.new)
    end

    context 'when an option is provided' do

      let(:monitor) do
        described_class.new(server.description, :heartbeat_frequency => 5)
      end

      it 'returns the option' do
        expect(monitor.heartbeat_frequency).to eq(5)
      end
    end

    context 'when no option is provided' do

      let(:monitor) do
        described_class.new(server.description)
      end

      it 'defaults to 5' do
        expect(monitor.heartbeat_frequency).to eq(10)
      end
    end
  end

  describe '#run!' do

    context 'when the description has not been GCed' do

      let(:server) do
        Mongo::Server.new(address, Mongo::Event::Listeners.new)
      end

      let(:monitor) do
        described_class.new(server.description, :heartbeat_frequency => 1)
      end

      before do
        monitor.run!
        sleep(1)
      end

      it 'refreshes the server on the provided interval' do
        expect(server.description).to_not be_nil
      end
    end

    context 'when the description has been GCed' do

      let(:address) do
        Mongo::Address.new('127.0.0.1:27017')
      end

      let(:description) do
         Mongo::Server::Description.new(address)
      end

      let(:monitor) do
        described_class.new(description, :heartbeat_frequency => 1)
      end

      let(:weakref) do
        monitor.instance_variable_get(:@description)
      end

      before do
        expect(weakref).to receive(:weakref_alive?).and_return(false)
      end

      it 'stops the monitor' do
        monitor.run!
        sleep(1.5)
        expect(monitor.instance_variable_get(:@thread)).to be_stop
      end
    end
  end
end
