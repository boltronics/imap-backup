# encoding: utf-8
require 'imap/backup/worker_base'

module Imap::Backup
  class Uploader < WorkerBase
    def run
      uids.each do |uid|
        message = serializer.load(uid)
        response = folder.append(message)
        new_uid = extract_uid(response)
        serializer.replace_uid(uid, new_uid)
      end
    end

    private

    def uids
      serializer.uids - folder.uids
    end

    def extract_uid(response)
      uid_validity, uid = response.data.code.data.split(' ')
      uid
    end
  end
end
