module EmailServerHelpers
  REQUESTED_ATTRIBUTES = ['RFC822', 'FLAGS', 'INTERNALDATE']

  def start_email_server
    Rake.application['test:email_server:start'].execute
  end

  def stop_email_server
    Rake.application['test:email_server:stop'].execute
  end

  def send_email(options)
    subject = options[:subject]
    body = options[:body]
    connection = fixture('connection')
    message = <<-EOT
From: #{connection[:username]}
Subject: #{subject}

#{body}
    EOT

    imap.append(folder_name, message, nil, nil)
  end

  def folder_name
    'INBOX'
  end

  def server_uids
    imap.examine(folder_name)
    imap.uid_search(['ALL']).sort
  end

  def server_messages
    server_uids.map do |uid|
      imap.uid_fetch([uid], REQUESTED_ATTRIBUTES)[0][1]
    end
  end

  def imap
    return @imap if @imap
    connection = fixture('connection')
    port = connection[:server_options][:port]
    @imap = Net::IMAP.new(connection[:server], port: port)
    @imap.login(connection[:username], connection[:password])
    @imap
  end
end

RSpec.configure do |config|
  config.include EmailServerHelpers, type: :feature
end
