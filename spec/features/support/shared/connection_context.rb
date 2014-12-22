shared_context 'imap-backup connection' do
  let(:local_backup_path) { Dir.mktmpdir(nil, 'tmp') }
  let(:connection_options) do
    {
      username: 'user@example.com',
      password: 'password',
      folders: [{name: 'INBOX'}],
      local_path: local_backup_path,
      server_options: {port: 1430},
    }
  end
  let(:connection) { Imap::Backup::Account::Connection.new(connection_options) }
end
