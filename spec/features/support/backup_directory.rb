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
    File.open(inbox_imap_path, 'a') { |f| f.puts uid }
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

  def inbox_imap_content
    File.read(inbox_imap_path)
  end
end

RSpec.configure do |config|
  config.include BackupDirectoryHelpers, type: :feature
end
