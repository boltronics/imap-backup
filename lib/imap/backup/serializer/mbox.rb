# encoding: utf-8
require 'csv'
require 'email/mboxrd/message'

module Imap::Backup
  module Serializer; end

  class Serializer::Mbox < Serializer::Base
    CURRENT_VERSION = 1

    attr_reader :prepared

    def initialize(path, folder)
      super
      @uids = nil
      @prepared = false
      @uid_validity = nil
    end

    def uids
      prepare
      return @uids if @uids

      @uids = []

      imap = load_imap
      return @uids if imap.nil?

      @uids = imap[:uids].map(&:to_i)
    end

    def save(uid, message)
      prepare
      uid = uid.to_i
      if uids.include?(uid)
        Imap::Backup.logger.debug "[#{folder}] message #{uid} already downloaded - skipping"
        return
      end

      body = message['RFC822']
      mboxrd_message = Email::Mboxrd::Message.new(body)
      mbox = nil
      begin
        mbox = File.open(mbox_pathname, 'ab')
        mbox.write mboxrd_message.to_serialized
        @uids << uid
        write_imap_file
      rescue => e
        Imap::Backup.logger.warn "[#{folder}] failed to save message #{uid}:\n#{body}. #{e}"
      ensure
        mbox.close if mbox
      end
    end

    def load(uid)
      prepare
      message_index = uids.find_index(uid)
      return nil if message_index.nil?
      load_nth(message_index)
    end

    def update_uid(old, new)
      prepare
      index = uids.find_index(old.to_i)
      return if index.nil?
      uids[index] = new.to_i
      write_imap_file
    end

    def update_uid_validity(value)
      case
      when uid_validity.nil?
        @uid_validity = value
      when uid_validity == value
        # NOOP
      else
        # rename files
        # return new name
      end
    end

    private

    def prepare
      return if prepared
      create_containing_directory
      check_files
      @prepared = true
    end

    def create_containing_directory
      mbox_relative_path = File.dirname(mbox_relative_pathname)
      return if mbox_relative_path == '.'
      Utils.make_folder(@path, mbox_relative_path, Serializer::DIRECTORY_PERMISSIONS)
    end

    def check_files
      imap = load_imap
      delete =
        case
        when (not mbox_exist?)
          true
        when imap.nil?
          true
        when imap[:version] != CURRENT_VERSION
          true
        when (not imap.has_key?(:uids))
          true
        when (not imap[:uids].is_a?(Array))
          true
        else
          false
        end
      delete_files if delete
    end

    def load_imap
      return nil unless imap_looks_like_json?
      JSON.parse(File.read(imap_pathname), :symbolize_names => true)
    rescue JSON::ParserError
      nil
    end

    def imap_looks_like_json?
      return false unless imap_exist?
      content = File.read(imap_pathname)
      content.start_with?('{')
    end

    def write_imap_file
      imap_data = {
        version: CURRENT_VERSION,
        uids: uids,
        uid_validity: uid_validity,
      }
      content = imap_data.to_json
      File.open(imap_pathname, 'w') { |f| f.write content }
    end

    def delete_files
      File.unlink(imap_pathname) if imap_exist?
      File.unlink(mbox_pathname) if mbox_exist?
    end

    def mbox_exist?
      File.exist?(mbox_pathname)
    end

    def imap_exist?
      File.exist?(imap_pathname)
    end

    def mbox_relative_pathname
      @folder + '.mbox'
    end

    def mbox_pathname
      File.join(@path, mbox_relative_pathname)
    end

    def imap_pathname
      filename = @folder + '.imap'
      File.join(@path, filename)
    end

    def load_nth(index)
      each_mbox_message.with_index do |raw, i|
        next unless i == index
        return Email::Mboxrd::Message.from_serialized(raw)
      end
      nil
    end

    def each_mbox_message
      Enumerator.new do |e|
        File.open(mbox_pathname) do |f|
          lines = []

          while line = f.gets
            if line.start_with?('From ')
              e.yield lines.join("\n") + "\n" if lines.count > 0
              lines = [line]
            else
              lines << line
            end
          end
          e.yield lines.join("\n") + "\n" if lines.count > 0
        end
      end
    end

    def uid_validity
      prepare
      return @uid_validity if @uid_validity

      imap = load_imap
      return nil if imap.nil?

      @uid_validity = imap[:uid_validity]
    end
  end
end
