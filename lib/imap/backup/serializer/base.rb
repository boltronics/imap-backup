# encoding: utf-8

module Imap::Backup
  module Serializer
    DIRECTORY_PERMISSIONS = 0700
    FILE_PERMISSIONS      = 0600

    class Base
      attr_reader :path
      attr_reader :folder

      def initialize(path, folder)
        @path, @folder = path, folder
      end
    end
  end
end
