# encoding: utf-8
#
require 'spec_helper'

describe Indexes do

  context 'after initialize' do
    let(:indexes) { described_class.new }
    it 'has no indexes' do
      indexes.indexes.should == []
    end
  end

  describe 'methods' do
    let(:indexes) { described_class.new }
    before(:each) do
      @index1 = stub :index1, :name => :index1
      @index2 = stub :index2, :name => :index2
      indexes.register @index1
      indexes.register @index2
    end
    describe 'index_for_tests' do
      it 'takes a snapshot, then indexes and caches each' do
        indexes.should_receive(:take_snapshot).once.with.ordered
        @index1.should_receive(:index).once.with.ordered
        @index2.should_receive(:index).once.with.ordered
      
        indexes.index_for_tests
      end
    end
    describe 'register' do
      it 'should have indexes' do
        indexes.indexes.should == [@index1, @index2]
      end
    end
    describe 'clear' do
      it 'clears the indexes' do
        indexes.clear
      
        indexes.indexes.should == []
      end
    end
    def self.it_delegates_each name
      describe name do
        it "calls #{name} on each in order" do
          @index1.should_receive(name).once.with.ordered
          @index2.should_receive(name).once.with.ordered

          indexes.send name
        end
      end
    end
    it_delegates_each :take_snapshot
    it_delegates_each :backup_caches
    it_delegates_each :restore_caches
    it_delegates_each :check_caches
    it_delegates_each :clear_caches
    it_delegates_each :create_directory_structure
  end
  
end