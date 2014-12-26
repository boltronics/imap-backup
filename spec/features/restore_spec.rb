require 'feature_helper'

RSpec.describe 'restore', type: :feature do
  include_context 'imap-backup connection'

  let(:uid1) { 123 }
  let(:uid2) { 345 }
  let(:msg1) { {uid: uid1, subject: 'Test 1', body: "body 1\nHi"} }
  let(:msg2) { {uid: uid2, subject: 'Test 2', body: "body 2"} }
  let(:post_restore_imap_data) { {version: 1, uids: [1, 2], uid_validity: 1} }
  let(:post_restore_imap_content) { post_restore_imap_data.to_json }

  before do
    start_email_server
    write_backup_email msg1
    write_backup_email msg2

    connection.restore
  end

  after do
    stop_email_server
    FileUtils.rm_rf local_backup_path
  end

  it 'restores' do
    expect(server_messages.count).to eq(2)
  end

  it 'updates local uids' do
    expect(read_inbox_imap).to eq(post_restore_imap_content)
  end
end
