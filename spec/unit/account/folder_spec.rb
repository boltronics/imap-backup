# encoding: utf-8
require 'spec_helper'

describe Imap::Backup::Account::Folder do
  let(:imap) { double('Net::IMAP', :examine => nil) }
  let(:connection) { double('Imap::Backup::Account::Connection', :imap => imap) }
  let(:missing_mailbox_data) { double('Data', :text => 'Unknown Mailbox: my_folder') }
  let(:missing_mailbox_response) { double('Response', :data => missing_mailbox_data) }
  let(:missing_mailbox_error) { Net::IMAP::NoResponseError.new(missing_mailbox_response) }

  subject { described_class.new(connection, 'my_folder') }

  context '#uids' do
    let(:uids) { %w(5678 123) }

    before { allow(imap).to receive(:uid_search).and_return(uids) }

    it 'lists available messages' do
      expect(subject.uids).to eq(uids.reverse)
    end

    context 'with missing mailboxes' do
      before { allow(imap).to receive(:examine).and_raise(missing_mailbox_error) }

      it 'returns an empty array' do
        expect(subject.uids).to eq([])
      end
    end
  end

  context '#fetch' do
    let(:message_body) { double('the body', :force_encoding => nil) }
    let(:message) { {'RFC822' => message_body, 'other' => 'xxx'} }

    before { allow(imap).to receive(:uid_fetch).and_return([[nil, message]]) }

    it 'returns the message' do
      expect(subject.fetch(123)).to eq(message)
    end

    context "if the mailbox doesn't exist" do
      before { allow(imap).to receive(:examine).and_raise(missing_mailbox_error) }

      it 'is nil' do
        expect(subject.fetch(123)).to be_nil
      end
    end

    if RUBY_VERSION > '1.9'
      it 'sets the encoding on the message' do
        subject.fetch(123)

        expect(message_body).to have_received(:force_encoding).with('utf-8')
      end
    end
  end
end
