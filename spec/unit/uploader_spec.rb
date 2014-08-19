# encoding: utf-8
require 'spec_helper'

describe Imap::Backup::Uploader do
  let(:imap) { double(Net::IMAP, append: :bar) }

  it 'skips uids already on the server'

  it 'uploads missing messages' do
    # set the date
    expect(imap).to have_received(:append).with(:foo)
  end

  it 'updates the local uid'
end
