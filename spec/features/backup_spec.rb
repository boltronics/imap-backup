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

    connection.run_backup
  end

  after do
    stop_email_server
    FileUtils.rm_rf local_backup_path
  end

  it 'downloads messages' do
    expect(inbox_mbox_content).to eq(messages_as_mbox)
  end

  it 'records IMAP ids' do
    expected = /\d+\n\d+/
    expect(inbox_imap_content).to match(expected)
  end
end
