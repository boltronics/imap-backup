# encoding: utf-8

require 'spec_helper'

describe Imap::Backup::Serializer::Mbox do
  let(:stat) { double('File::Stat', :mode => 0700) }
  let(:base_path) { '/base/path' }
  let(:mbox_pathname) { '/base/path/my/folder.mbox' }
  let(:mbox_exists) { true }
  let(:imap_pathname) { '/base/path/my/folder.imap' }
  let(:imap_exists) { true }

  before do
    allow(Imap::Backup::Utils).to receive(:make_folder)
    allow(File).to receive(:exist?).with(base_path).and_return(true)
    allow(File).to receive(:stat).with(base_path).and_return(stat)
    allow(File).to receive(:exist?).with(mbox_pathname).and_return(mbox_exists)
    allow(File).to receive(:exist?).with(imap_pathname).and_return(imap_exists)
  end

  context '#initialize' do
    it 'creates the containing directory' do
      described_class.new(base_path, 'my/folder')

      expect(Imap::Backup::Utils).to have_received(:make_folder).with(base_path, 'my', 0700)
    end

    context 'mbox and imap files' do
      context "if mbox exists and imap doesn't" do
        let(:imap_exists) { false }

        it 'fails' do
          expect {
            described_class.new(base_path, 'my/folder')
          }.to raise_error(RuntimeError, '.imap file missing')
        end
      end

      context "if imap exists and mbox doesn't" do
        let(:mbox_exists) { false }

        it 'fails' do
          expect {
            described_class.new(base_path, 'my/folder')
          }.to raise_error(RuntimeError, '.mbox file missing')
        end
      end
    end
  end

  context 'instance methods' do
    let(:ids) { %w(3 2 1) }

    before do
      allow(CSV).to receive(:foreach) { |&b| ids.each { |id| b.call [id] } }
    end

    subject { described_class.new(base_path, 'my/folder') }

    context '#uids' do
      it 'returns the backed-up uids as sorted integers' do
        expect(subject.uids).to eq(ids.map(&:to_i).sort)
      end

      context 'if the mbox does not exist' do
        let(:mbox_exists) { false }
        let(:imap_exists) { false }

        it 'returns an empty Array' do
          expect(subject.uids).to eq([])
        end
      end
    end

    context '#save' do
      let(:mbox_formatted_message) { 'message in mbox format' }
      let(:message_uid) { '999' }
      let(:message) { double('Email::Mboxrd::Message', to_serialized: mbox_formatted_message) }
      let(:mbox_file) { double('File - mbox', :write => nil, :close => nil) }
      let(:imap_file) { double('File - imap', :write => nil, :close => nil) }

      before do
        allow(Email::Mboxrd::Message).to receive(:new).and_return(message)
        allow(File).to receive(:open).with(mbox_pathname, 'ab').and_return(mbox_file)
        allow(File).to receive(:open).with(imap_pathname, 'ab').and_return(imap_file)
      end

      it 'saves the message to the mbox' do
        subject.save(message_uid, "The\nemail\n")

        expect(mbox_file).to have_received(:write).with(mbox_formatted_message)
      end

      it 'saves the uid to the imap file' do
        subject.save(message_uid, "The\nemail\n")

        expect(imap_file).to have_received(:write).with(message_uid + "\n")
      end

      context 'when the message causes parsing errors' do
        before do
          allow(message).to receive(:to_serialized).and_raise(ArgumentError)
        end

        it 'skips the message' do
          subject.save(message_uid, "The\nemail\n")
          expect(mbox_file).to_not have_received(:write)
        end

        it 'does not fail' do
          expect do
            subject.save(message_uid, "The\nemail\n")
          end.to_not raise_error
        end
      end
    end

    describe '#load' do
      let(:ids) { ['foo', uid] }
      let(:uid) { '1' }

      context 'with missing uids' do
        let(:ids) { ['999'] }

        it 'returns nil' do
          expect(subject.load(uid)).to be_nil
        end
      end

      context 'with uids present in the imap file' do
        let(:mbox_file) { double(File) }
        let(:message) { double(Email::Mboxrd::Message) }
        let(:first_message) { "From You\nDelivered-To: me@example.com\n" }
        let(:second_message) { "From Me\nDelivered-To: you@example.com\n" }
        let(:mbox_lines) { (first_message + second_message).split("\n") }

        before do
          allow(File).to receive(:open).with(mbox_pathname) { |&blk| blk.call(mbox_file) }
          allow(mbox_file).to receive(:gets).and_return(*mbox_lines, nil)
          allow(Email::Mboxrd::Message).to receive(:from_serialized).with(second_message).and_return(message)
        end

        it 'returns the message' do
          expect(subject.load(uid)).to eq(message)
        end
      end
    end

    describe '#update_uid' do
      let(:ids) { ['8', '9'] }
      let(:imap_output) { "8\n99\n" }
      let(:imap_file) { double('File - imap', write: nil, close: nil) }

      before do
        allow(File).to receive(:open).with(imap_pathname, 'wb').and_return(imap_file)
      end

      before { subject.update_uid('9', '99') }

      it 'saves the modified imap file' do
        expect(imap_file).to have_received(:write).with(imap_output)
      end

      context 'with unknown uids' do
        let(:ids) { ['8', '10'] }

        it 'does nothing' do
          expect(imap_file).to_not have_received(:write)
        end
      end
    end
  end
end
