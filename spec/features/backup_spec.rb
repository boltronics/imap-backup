require 'feature_helper'

RSpec.describe 'backup', type: :feature do
  before { start_email_server }
  after { stop_email_server }

  let(:local_path) { Dir.mktmpdir(nil, 'tmp') }
  let(:msg1) { {subject: 'Test 1', body: "body 1\nHi"} }
  let(:msg2) { {subject: 'Test 2', body: "body 2"} }
  let(:messages_as_mbox) do
    message_as_mbox_entry(msg1) + message_as_mbox_entry(msg2)
  end

  let(:inbox_mbox_path) { File.join(local_path, 'INBOX.mbox') }
  let(:inbox_mbox_content) { File.read(inbox_mbox_path) }

  before do
    send_email msg1
    send_email msg2

    options = {
      username: 'user@example.com',
      password: 'password',
      folders: [{name: 'INBOX'}],
      local_path: local_path,
      server_options: {port: 1430},
    }
    connection = Imap::Backup::Account::Connection.new(options)
    connection.run_backup
  end

  after do
    FileUtils.rm_rf local_path
  end

  it 'downloads messages' do
    expect(inbox_mbox_content).to eq(messages_as_mbox)
  end
end
