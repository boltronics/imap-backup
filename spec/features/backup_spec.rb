require 'feature_helper'

RSpec.describe 'backup', type: :feature do
  include_context 'imap-backup connection'
  include_context 'message-fixtures'

  let(:messages_as_mbox) do
    message_as_mbox_entry(msg1) + message_as_mbox_entry(msg2)
  end

  before do
    start_email_server
    send_email msg1
    send_email msg2
  end

  after do
    stop_email_server
    FileUtils.rm_rf local_backup_path
  end

  it 'downloads messages' do
    connection.run_backup

    expect(mbox_content('INBOX')).to eq(messages_as_mbox)
  end

  it 'records IMAP ids' do
    connection.run_backup

    expect(imap_parsed('INBOX')[:uids]).to eq([1, 2])
  end

  it 'records folder UID validity' do
    connection.run_backup

    imap = imap_parsed('INBOX')
    expect(imap[:uid_validity]).to eq(1)
  end

  context 'when UID validity changes due to a folder rename' do
    let(:original_inbox_uid_validity) { 99999 }
    let(:renamed_inbox_name) { "INBOX.#{original_inbox_uid_validity}" }

    before do
      set_uid_validity 'INBOX', 99999
      write_backup_email 'INBOX', msg3

      connection.run_backup
    end

    it 'renames the local mbox' do
      old_inbox = imap_parsed(renamed_inbox_name)

      expect(old_inbox[:uid_validity]).to eq(original_inbox_uid_validity)
      expect(old_inbox[:uids]).to eq([uid3])
    end

    it 'renames the local imap' do
      expect(mbox_content(renamed_inbox_name)).to eq(message_as_mbox_entry(msg3))
    end

    it 'downloads messages to a new mbox' do
      expect(mbox_content('INBOX')).to eq(messages_as_mbox)
    end

    it 'records new IMAP ids' do
      expect(imap_parsed('INBOX')[:uids]).to eq([1, 2])
    end
  end

  context 'when no local version is found' do
    before do
      File.open(imap_path('INBOX'), 'w') { |f| f.write 'old format imap' }
      File.open(mbox_path('INBOX'), 'w') { |f| f.write 'old format emails' }

      connection.run_backup
    end

    it 'replaces the .imap file with a versioned JSON file' do
      imap = imap_parsed('INBOX')

      expect(imap[:uids].map(&:to_i)).to eq(server_uids)
    end

    it 'does the download' do
      expect(mbox_content('INBOX')).to eq(messages_as_mbox)
    end
  end
end
