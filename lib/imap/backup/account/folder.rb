# encoding: utf-8
require 'forwardable'

module Imap::Backup
  module Account; end

  class Account::Folder
    extend Forwardable

    REQUESTED_ATTRIBUTES = ['RFC822', 'FLAGS', 'INTERNALDATE']

    attr_reader :connection
    attr_reader :name

    delegate imap: :connection

    def initialize(connection, name)
      @connection = connection
      @name = name
    end

    def folder
      name
    end

    def uids
      imap.examine(name)
      imap.uid_search(['ALL']).sort.map(&:to_s)
    rescue Net::IMAP::NoResponseError => e
      Imap::Backup.logger.warn "Folder '#{name}' does not exist"
      []
    end

    def fetch(uid)
      imap.examine(name)
      message = imap.uid_fetch([uid.to_i], REQUESTED_ATTRIBUTES)[0][1]
      message['RFC822'].force_encoding('utf-8') if RUBY_VERSION > '1.9'
      message
    rescue Net::IMAP::NoResponseError => e
      Imap::Backup.logger.warn "Folder '#{name}' does not exist"
      nil
    end

    def append(message)
      response = imap.append(name, message.to_s, nil, message.date)
      extract_uid(response)
    end

    private

    def extract_uid(response)
      uid_validity, uid = response.data.code.data.split(' ')
      uid.to_i
    end
  end
end
