require 'feature_helper'

RSpec.describe 'restore', type: :feature do
  include_context 'imap-backup connection'

  let(:msg1) { {uid: 123, subject: 'Test 1', body: "body 1\nHi"} }
  let(:msg2) { {uid: 345, subject: 'Test 2', body: "body 2"} }

  before do
    start_email_server
    write_backup_email msg1
    write_backup_email msg2
  end

  after do
    stop_email_server
    FileUtils.rm_rf local_backup_path
  end

  it 'restores' do
    connection.restore
  end
end
