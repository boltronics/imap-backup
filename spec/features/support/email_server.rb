module RSpecFeatureHelpers
  def start_email_server
    Rake.application['test:email_server:start'].execute
  end

  def stop_email_server
    Rake.application['test:email_server:stop'].execute
  end

  def message_as_mbox_entry(options)
    subject = options[:subject]
    body = options[:body]
    <<-EOT
From user@example.com 
From: user@example.com
Subject: #{subject}

#{body}

    EOT
  end

  def send_email(options)
    subject = options[:subject]
    body = options[:body]
    message = <<-EOT
From: #{username}
Subject: #{subject}

#{body}
    EOT

    imap.append('INBOX', message, nil, nil)
  end

  def username
    'user@example.com'
  end

  def imap
    imap = Net::IMAP.new('localhost', port: '1430')
    imap.login(username, 'password')
    imap
  end
end
