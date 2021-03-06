# encoding: utf-8
#
require 'spec_helper'

describe Picky::Generators::Similarity::Metaphone do

  before(:each) do
    @similarity = described_class.new
  end

  describe 'default amount' do
    it 'is correct' do
      @similarity.amount.should == 3
    end
  end

  def self.it_should_encode text, expected
    it "should encode #{text.inspect} correctly" do
      @similarity.encode(text).should == expected
    end
  end

  it_should_encode :meier,       :MR
  it_should_encode :grossberger, :KRSBRJR
  it_should_encode :hadelbla,    :HTLBL

end