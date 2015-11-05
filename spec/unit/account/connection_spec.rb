# encoding: utf-8
require 'spec_helper'

module Imap::Backup
  describe Account::Connection do
    def self.backup_folder
      'backup_folder'
    end

    def self.folder_config
      {:name => backup_folder}
    end

    let(:imap) { double('Net::IMAP', :login => nil, :list => imap_folders, :disconnect => nil) }
    let(:imap_folders) { [] }
    let(:options) do
      {
        :username => username,
        :password => 'password',
        :local_path => local_path,
        :folders => backup_folders,
      }
    end
    let(:local_path) { 'local_path' }
    let(:backup_folders) { [self.class.folder_config] }
    let(:username) { 'username@gmail.com' }

    before do
      allow(Net::IMAP).to receive(:new).and_return(imap)
    end

    subject { described_class.new(options) }

    shared_examples 'connects to IMAP' do
      it 'sets up the IMAP connection' do
        expect(Net::IMAP).to have_received(:new)
      end

      it 'logs in to the imap server' do
        expect(imap).to have_received(:login)
      end
    end

    context '#initialize' do
      [
        [:username, 'username@gmail.com'],
        [:local_path, 'local_path'],
        [:backup_folders, [folder_config]],
      ].each do |attr, expected|
        it "expects #{attr}" do
          expect(subject.send(attr)).to eq(expected)
        end
      end
    end

    describe '#imap' do
      before { @result = subject.imap }

      it 'returns the IMAP connection' do
        expect(@result).to eq(imap)
      end

      include_examples 'connects to IMAP'
    end

    context '#folders' do
      let(:imap_folders) { ['imap_folder'] }

      before { allow(imap).to receive(:list).and_return(imap_folders) }

      it 'returns the list of folders' do
        expect(subject.folders).to eq(imap_folders)
      end
    end

    context '#status' do
      let(:folder) { instance_double(Account::Folder, :uids => [remote_uid]) }
      let(:local_uid) { 'local_uid' }
      let(:serializer) { instance_double(Serializer::Mbox, :uids => [local_uid]) }
      let(:remote_uid) { 'remote_uid' }

      before do
        allow(Account::Folder).to receive(:new).and_return(folder)
        allow(Serializer::Mbox).to receive(:new).and_return(serializer)
      end

      it 'should return the names of folders' do
        expect(subject.status[0][:name]).to eq(self.class.backup_folder)
      end

      it 'returns local message uids' do
        expect(subject.status[0][:local]).to eq([local_uid])
      end

      it 'should retrieve the available uids' do
        expect(subject.status[0][:remote]).to eq([remote_uid])
      end
    end

    context '#run_backup' do
      let(:folder) { instance_double(Account::Folder, :name => 'foo', :uid_validity => 1) }
      let(:serializer) { instance_double(Serializer::Mbox, :set_uid_validity => nil) }
      let(:downloader) { double('downloader', :run => nil) }

      before do
        allow(Downloader).to receive(:new).and_return(downloader)
      end

      context 'with supplied backup_folders' do
        before do
          allow(Account::Folder).to receive(:new).
            with(subject, self.class.backup_folder).and_return(folder)
          allow(Serializer::Mbox).to receive(:new).
            with(local_path, self.class.backup_folder).and_return(serializer)
        end

        before { subject.run_backup }

        it 'runs the downloader' do
          expect(downloader).to have_received(:run)
        end
      end

      context 'without supplied backup_folders' do
        let(:imap_folders) { [double(:name => 'foo')] }

        before do
          allow(Account::Folder).to receive(:new).
            with(subject, 'foo').and_return(folder)
          allow(Serializer::Mbox).to receive(:new).
            with(local_path, 'foo').and_return(serializer)
        end

        context 'when supplied backup_folders is nil' do
          let(:backup_folders) { nil }

          before { subject.run_backup }

          it 'runs the downloader' do
            expect(downloader).to have_received(:run)
          end
        end

        context 'when supplied backup_folders is an empty list' do
          let(:backup_folders) { [] }

          before { subject.run_backup }

          it 'runs the downloader' do
            expect(downloader).to have_received(:run)
          end
        end

        context "when the imap server doesn't return folders" do
          let(:backup_folders) { nil }
          let(:imap_folders) { nil }

          it 'does not fail' do
            expect { subject.run_backup }.to_not raise_error
          end
        end
      end
    end

    context '#disconnect' do
      before { subject.disconnect }

      it 'disconnects from the server' do
        expect(imap).to have_received(:disconnect)
      end

      include_examples 'connects to IMAP'
    end
  end
end
