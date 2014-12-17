module RSpecFeatureHelpers
  def start_email_server
    Rake.application.invoke_task 'test:email_server:start'
    sleep 0.1
  end

  def stop_email_server
    Rake.application.invoke_task 'test:email_server:stop'
  end

  def send_email(subject: nil, body: nil)
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
