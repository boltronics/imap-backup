# encoding: utf-8

require 'spec_helper'

describe Email::Mboxrd::Message do
  let(:from) { 'me@example.com' }
  let(:date) { DateTime.new(2012, 12, 13, 18, 23, 45) }
  let(:message_body) do
    double('Body', :clone => cloned_message_body, :force_encoding => nil)
  end
  let(:cloned_message_body) { "Foo\nBar\nFrom at the beginning of the line\n>>From quoted" }

  subject { described_class.new(message_body) }

  context '#to_serialized' do
    let(:mail) { double('Mail', :from =>[from], :date => date) }

    before do
      allow(Mail).to receive(:new).with(cloned_message_body).and_return(mail)
    end

    it 'does not modify the message' do
      subject.to_serialized

      expect(message_body).to_not have_received(:force_encoding).with('binary')
    end

    it "adds a 'From ' line at the start" do
      expect(subject.to_serialized).to start_with('From ' + from + ' ' + date.asctime + "\n")
    end

    it "replaces existing 'From ' with '>From '" do
      expect(subject.to_serialized).to include("\n>From at the beginning")
    end

    it "appends > before '>+From '" do
      expect(subject.to_serialized).to include("\n>>>From quoted")
    end

    context 'when date is missing' do
      let(:date) { nil }

      it 'does no fail' do
        expect { subject.to_s }.to_not raise_error
      end
    end
  end
end
