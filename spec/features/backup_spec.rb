require 'feature_helper'

RSpec.describe 'backup', type: :feature do
  include_context 'imap-backup connection'

  let(:msg1) { {subject: 'Test 1', body: "body 1\nHi"} }
  let(:msg2) { {subject: 'Test 2', body: "body 2"} }
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

    expect(inbox_mbox_content).to eq(messages_as_mbox)
  end

  it 'records IMAP ids' do
    connection.run_backup

    expect(inbox_imap_parsed[:uids]).to eq([1, 2])
  end

  it 'records folder UID validity' do
    connection.run_backup

    expect(inbox_imap_parsed[:uid_validity]).to eq(1)
  end

  context 'when no local version is found' do
    before do
      File.open(inbox_imap_path, 'w') { |f| f.write 'old format imap' }
      File.open(inbox_mbox_path, 'w') { |f| f.write 'old format emails' }

      connection.run_backup
    end

    it 'replaces the .imap file with a versioned JSON file' do
      imap = JSON.parse(read_inbox_imap, :symbolize_names => true)

      expect(imap[:uids].map(&:to_i)).to eq(server_uids)
    end

    it 'does the download' do
      expect(inbox_mbox_content).to eq(messages_as_mbox)
    end
  end
end
