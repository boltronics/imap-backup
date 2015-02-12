# encoding: utf-8

require 'spec_helper'

describe Imap::Backup::Serializer::Mbox do
  def imap_data(uid_validity, uids)
    {version: 1, uids: uids, uid_validity: uid_validity}
  end

  let(:stat) { double('File::Stat', :mode => 0700) }
  let(:base_path) { '/base/path' }
  let(:imap_folder) { 'my/folder' }
  let(:base_directory_exists) { true }
  let(:mbox_pathname) { File.join(base_path, imap_folder + '.mbox') }
  let(:mbox_exists) { true }
  let(:imap_pathname) { File.join(base_path, imap_folder + '.imap') }
  let(:imap_exists) { true }
  let(:serialized_uids) { [3, 2, 1] }
  let(:imap_content) { imap_data(uid_validity, serialized_uids).to_json }
  let(:uid_validity)  { 555 }

  subject { described_class.new(base_path, imap_folder) }

  before do
    allow(Imap::Backup::Utils).to receive(:make_folder)
    allow(File).to receive(:exist?).with(base_path).and_return(base_directory_exists)
    allow(File).to receive(:stat).with(base_path).and_return(stat)
    allow(File).to receive(:exist?).with(mbox_pathname).and_return(mbox_exists)
    allow(File).to receive(:exist?).with(imap_pathname).and_return(imap_exists)
    allow(File).to receive(:read).with(imap_pathname).and_return(imap_content)
    allow(File).to receive(:unlink).with(imap_pathname)
    allow(File).to receive(:unlink).with(mbox_pathname)
  end

  shared_examples 'file setup' do
    context 'when the containing directory does not exist' do
      let(:base_directory_exists) { false }

      it 'is created' do
        expect(Imap::Backup::Utils).to have_received(:make_folder).with(base_path, File.dirname(imap_folder), 0700)
      end
    end

    context "when the mbox doesn't exist" do
      let(:mbox_exists) { false }

      it 'deletes the imap file' do
        expect(File).to have_received(:unlink).with(imap_pathname)
      end
    end

    context "when the mbox exists" do
      context "when the imap doesn't exist" do
        let(:imap_exists) { false }

        it 'deletes the mbox' do
          expect(File).to have_received(:unlink).with(mbox_pathname)
        end
      end

      context "when the imap isn't JSON" do
        let(:imap_content) { 'xxx' }

        it 'deletes the mbox' do
          expect(File).to have_received(:unlink).with(mbox_pathname)
        end
      end

      context "when the imap has no version" do
        let(:data) { data = imap_data(uid_validity, serialized_uids); data.delete(:version); data }
        let(:imap_content) { data.to_json }

        it 'deletes the mbox' do
          expect(File).to have_received(:unlink).with(mbox_pathname)
        end
      end

      context 'when the imap is acceptable' do
        it "doesn't delete the mbox" do
          expect(File).to_not have_received(:unlink).with(mbox_pathname)
        end
      end
    end
  end

  context '#uids' do
    context 'file setup' do
      include_examples 'file setup' do
        before { subject.uids }
      end
    end

    it 'returns the backed-up uids as integers' do
      expect(subject.uids).to eq(serialized_uids.map(&:to_i))
    end

    context 'if the imap file does not exist' do
      let(:mbox_exists) { false }
      let(:imap_exists) { false }

      it 'returns an empty Array' do
        expect(subject.uids).to eq([])
      end
    end
  end

  context '#save' do
    let(:mbox_formatted_message) { 'message in mbox format' }
    let(:new_uid) { 999 }
    let(:new_uids) { serialized_uids + [new_uid] }
    let(:new_content) { imap_data(uid_validity, new_uids).to_json }
    let(:message) { double('Email::Mboxrd::Message', to_serialized: mbox_formatted_message) }
    let(:serialized) { "The\nemail\n" }
    let(:mbox_file) { double('File - mbox', :write => nil, :close => nil) }
    let(:imap_file) { double('File - imap', :write => nil, :close => nil) }

    before do
      allow(Email::Mboxrd::Message).to receive(:new).and_return(message)
      allow(File).to receive(:open).with(mbox_pathname, 'ab').and_return(mbox_file)
      allow(File).to receive(:open).with(imap_pathname, 'w').and_yield(imap_file)
      subject.uid_validity = uid_validity
    end

    it 'saves the message to the mbox' do
      subject.save(new_uid, serialized)

      expect(mbox_file).to have_received(:write).with(mbox_formatted_message)
    end

    it 'saves the uid to the imap file' do
      subject.save(new_uid, serialized)

      expect(imap_file).to have_received(:write).with(new_content)
    end

    context 'when the message causes parsing errors' do
      before do
        allow(message).to receive(:to_serialized).and_raise(ArgumentError)
      end

      it 'skips the message' do
        subject.save(new_uid, serialized)
        expect(mbox_file).to_not have_received(:write)
      end

      it 'does not fail' do
        expect do
          subject.save(new_uid, serialized)
        end.to_not raise_error
      end
    end

    context 'file setup' do
      include_examples 'file setup' do
        before { subject.save(new_uid, serialized) }
      end
    end
  end

  describe '#load' do
    let(:serialized_uids) { [666, uid.to_s] }
    let(:uid) { 1 }

    context 'with missing uids' do
      let(:serialized_uids) { [999] }

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
    let(:old_uid) { 9 }
    let(:serialized_uids) { [8, old_uid] }
    let(:new_uid) { 99 }
    let(:new_uids) { [8, new_uid] }
    let(:new_content) { imap_data(uid_validity, new_uids).to_json }
    let(:imap_file) { double('File - imap', write: nil, close: nil) }

    before do
      allow(File).to receive(:open).with(imap_pathname, 'w').and_yield(imap_file)
      subject.uid_validity = uid_validity
    end

    before { subject.update_uid(old_uid, new_uid) }

    it 'saves the modified imap file' do
      expect(imap_file).to have_received(:write).with(new_content)
    end

    context 'with unknown uids' do
      let(:serialized_uids) { [8, 10] }

      it 'does nothing' do
        expect(imap_file).to_not have_received(:write)
      end
    end
  end

  context '#update_uid_validity' do
    before { subject.uid_validity = uid_validity }

    it 'loads the value from the imap file'

    context "when a backup doesn't exist" do
      it 'does nothing'
    end

    context 'when the value is the same' do
      it 'does nothing'
    end

    context "when the value changes" do
      it 'saves a blank mbox file' do
        expect(mbox_file).to have_received(:write).with(new_content)
      end

      it 'saves a new imap file' do
        expect(imap_file).to have_received(:write).with(new_content)
      end

      it 'renames the mbox file'
      it 'renames the imap file'
      it 'returns the new name'

      context 'when the rename causes a clash' do
        it 'adds digits until it finds a unique name'
      end
    end
  end
end
