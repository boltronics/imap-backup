module BackupDirectoryHelpers
  def message_as_mbox_entry(options)
    subject = options[:subject]
    body = options[:body]
    <<-EOT
From user@example.com 
>From: user@example.com
Subject: #{subject}

#{body}

    EOT
  end

  def write_backup_email(msg)
    add_backup_uid msg[:uid]
    File.open(inbox_mbox_path, 'a') { |f| f.write message_as_mbox_entry(msg) }
  end

  def add_backup_uid(uid)
    imap = load_or_create_imap
    imap[:uids] << uid
    File.open(inbox_imap_path, 'w') { |f| f.puts imap.to_json }
  end

  def inbox_mbox_path
    File.join(local_backup_path, 'INBOX.mbox')
  end

  def inbox_imap_path
    File.join(local_backup_path, 'INBOX.imap')
  end

  def inbox_mbox_content
    File.read(inbox_mbox_path)
  end

  def read_inbox_imap
    File.read(inbox_imap_path)
  end

  def load_or_create_imap
    if File.exist?(inbox_imap_path)
      JSON.parse(read_inbox_imap, :symbolize_names => true)
    else
      {version: 1, uids: []}
    end
  end
end

RSpec.configure do |config|
  config.include BackupDirectoryHelpers, type: :feature
end
