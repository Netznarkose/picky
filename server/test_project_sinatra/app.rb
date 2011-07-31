# encoding: utf-8
#

# Stresstest using
#   ab -kc 5 -t 5 http://127.0.0.1:4567/csv?query=t
#

require 'sinatra/base'
require File.expand_path '../../lib/picky', __FILE__

class ChangingItem

  attr_reader :id, :name

  def initialize id, name
    @id, @name = id, name
  end

end

class BookSearch < Sinatra::Application

  include Picky

  extend Picky::Sinatra

  indexing removes_characters:                 /[^äöüa-zA-Z0-9\s\/\-\_\:\"\&\.\|]/i,
           stopwords:                          /\b(and|the|or|on|of|in|is|to|from|as|at|an)\b/i,
           splits_text_on:                     /[\s\/\-\_\:\"\&\/]/,
           removes_characters_after_splitting: /[\.]/,
           normalizes_words:                   [[/\$(\w+)/i, '\1 dollars']],
           rejects_token_if:                   lambda { |token| token.blank? || token == :amistad },
           case_sensitive:                     false,

           substitutes_characters_with:        CharacterSubstituters::WestEuropean.new

  searching removes_characters:                 /[^ïôåñëäöüa-zA-Z0-9\s\/\-\_\,\&\.\"\~\*\:]/i,
            stopwords:                          /\b(and|the|or|on|of|in|is|to|from|as|at|an)\b/i,
            splits_text_on:                     /[\s\/\&\/]/,
            removes_characters_after_splitting: /\|/,
            # rejects_token_if:                   lambda { |token| token.blank? || token == :hell }, # Not yet.
            case_sensitive:                     true,

            maximum_tokens:                     5,
            substitutes_characters_with:        CharacterSubstituters::WestEuropean.new

  books_index = Indexes::Memory.new :books, result_identifier: 'boooookies' do
    source   Sources::DB.new('SELECT id, title, author, year FROM books', file: 'db.yml')
    category :id
    category :title,
             qualifiers: [:t, :title, :titre],
             partial:    Partial::Substring.new(:from => 1),
             similarity: Similarity::DoubleMetaphone.new(2)
    category :author, partial: Partial::Substring.new(:from => -2)
    category :year, qualifiers: [:y, :year, :annee]
  end

  class Book < ActiveRecord::Base; end
  Book.establish_connection YAML.load(File.open('db.yml'))
  book_each_index = Indexes::Memory.new :book_each do
    key_format :to_s
    source     Book.order('title ASC')
    category   :id
    category   :title,
               qualifiers: [:t, :title, :titre],
               partial:    Partial::Substring.new(:from => 1),
               similarity: Similarity::DoubleMetaphone.new(2)
    category   :author, partial: Partial::Substring.new(:from => -2)
    category   :year, qualifiers: [:y, :year, :annee]
  end

  isbn_index = Indexes::Memory.new :isbn do
    source   Sources::DB.new("SELECT id, isbn FROM books", :file => 'db.yml')
    category :isbn, :qualifiers => [:i, :isbn]
  end

  class EachRSSItemProxy

    def each &block
      require 'rss'
      require 'open-uri'
      rss_feed = "http://florianhanke.com/blog/atom.xml"
      rss_content = ""
      open rss_feed do |f|
         rss_content = f.read
      end
      rss = RSS::Parser.parse rss_content, true
      rss.items.each &block
    rescue
      # Don't call block, no data.
    end

  end

  rss_index = Indexes::Memory.new :rss do
    source     EachRSSItemProxy.new
    key_format :to_s

    category   :title
    # etc...
  end

  # Breaking example to test the nice error message.
  #
  # breaking = Indexes::Memory.new :isbn, Sources::DB.new("SELECT id, isbn FROM books", :file => 'db.yml') do
  #   category :isbn, :qualifiers => [:i, :isbn]
  # end

  # Fake ISBN class to demonstrate that #each indexing is working.
  #
  class ISBN
    @@id = 1
    attr_reader :id, :isbn
    def initialize isbn
      @id   = @@id += 1
      @isbn = isbn
    end
  end
  isbn_each_index = Indexes::Memory.new :isbn_each, source: [ISBN.new('ABC'), ISBN.new('DEF')] do
    category :isbn, :qualifiers => [:i, :isbn], :key_format => :to_s
  end

  mgeo_index = Indexes::Memory.new :memory_geo do
    source          Sources::CSV.new(:location, :north, :east, file: 'data/ch.csv', col_sep: ',')
    category        :location
    ranged_category :north1, 0.008, precision: 3, from: :north
    ranged_category :east1,  0.008, precision: 3, from: :east
  end

  real_geo_index = Indexes::Memory.new :real_geo do
    source         Sources::CSV.new(:location, :north, :east, file: 'data/ch.csv', col_sep: ',')
    category       :location, partial: Partial::Substring.new(from: 1)
    geo_categories :north, :east, 1, precision: 3
  end

  iphone_locations = Indexes::Memory.new :iphone do
    source Sources::CSV.new(
      :mcc,
      :mnc,
      :lac,
      :ci,
      :timestamp,
      :latitude,
      :longitude,
      :horizontal_accuracy,
      :altitude,
      :vertical_accuracy,
      :speed,
      :course,
      :confidence,
      file: 'data/iphone_locations.csv'
    )
    ranged_category :timestamp, 86_400, precision: 5, qualifiers: [:ts, :timestamp]
    geo_categories  :latitude, :longitude, 25, precision: 3
  end

  Indexes::Memory.new :underscore_regression do
    source         Sources::CSV.new(:location, file: 'data/ch.csv')
    category       :some_place, :from => :location
  end

  # rgeo_index = Indexes::Redis.new :redis_geo, Sources::CSV.new(:location, :north, :east, file: 'data/ch.csv', col_sep: ',')
  # rgeo_index.define_category :location
  # rgeo_index.define_map_location(:north1, 1, precision: 3, from: :north)
  #           .define_map_location(:east1,  1, precision: 3, from: :east)

  csv_test_index = Indexes::Memory.new(:csv_test, result_identifier: 'Books') do
    source     Sources::CSV.new(:title,:author,:isbn,:year,:publisher,:subjects, file: 'data/books.csv')

    category :title,
             qualifiers: [:t, :title, :titre],
             partial:    Partial::Substring.new(from: 1),
             similarity: Similarity::DoubleMetaphone.new(2)
    category :author,
             qualifiers: [:a, :author, :auteur],
             partial:    Partial::Substring.new(from: -2)
    category :year,
             qualifiers: [:y, :year, :annee],
             partial:    Partial::None.new
    category :publisher, qualifiers: [:p, :publisher]
    category :subjects, qualifiers: [:s, :subject]
  end

  indexing_index = Indexes::Memory.new(:special_indexing) do
    source   Sources::CSV.new(:title, file: 'data/books.csv')
    indexing removes_characters: /[^äöüd-zD-Z0-9\s\/\-\"\&\.]/i, # a-c, A-C are removed
             splits_text_on:     /[\s\/\-\"\&\/]/
    category :title,
             qualifiers: [:t, :title, :titre],
             partial:    Partial::Substring.new(from: 1),
             similarity: Similarity::DoubleMetaphone.new(2)
  end

  redis_index = Indexes::Redis.new(:redis) do
  source   Sources::CSV.new(:title, :author, :isbn, :year, :publisher, :subjects, file: 'data/books.csv')
    category :title,
             qualifiers: [:t, :title, :titre],
             partial:    Partial::Substring.new(from: 1),
             similarity: Similarity::DoubleMetaphone.new(2)
    category :author,
             qualifiers: [:a, :author, :auteur],
             partial:    Partial::Substring.new(from: -2)
    category :year,
             qualifiers: [:y, :year, :annee],
             partial:    Partial::None.new
    category :publisher, qualifiers: [:p, :publisher]
    category :subjects,  qualifiers: [:s, :subject]
  end

  sym_keys_index = Indexes::Memory.new :symbol_keys do
    source   Sources::CSV.new(:text, file: "data/#{PICKY_ENVIRONMENT}/symbol_keys.csv", key_format: 'strip')
    category :text, partial: Partial::Substring.new(from: 1)
  end

  memory_changing_index = Indexes::Memory.new(:memory_changing) do
    source [
      ChangingItem.new("1", 'first entry'),
      ChangingItem.new("2", 'second entry'),
      ChangingItem.new("3", 'third entry')
    ]
    category :name
  end

  redis_changing_index = Indexes::Redis.new(:redis_changing) do
    source [
      ChangingItem.new("1", 'first entry'),
      ChangingItem.new("2", 'second entry'),
      ChangingItem.new("3", 'third entry')
    ]
    category :name
  end

  Indexes.reload

  options = {
    :weights => {
      [:author]         => 6,
      [:title, :author] => 5,
      [:author, :year]  => 2
    }
  }

  # This looks horrible – but usually you have it only once.
  # It's flexible.
  #
  books_search = Search.new books_index, isbn_index, options
  get %r{\A/books\Z} do
    books_search.search_with_text(params[:query], params[:ids] || 20, params[:offset] || 0).to_json
  end
  book_each_search = Search.new book_each_index, options
  get %r{\A/book_each\Z} do
    book_each_search.search_with_text(params[:query], params[:ids] || 20, params[:offset] || 0).to_json
  end
  redis_search = Search.new redis_index, options
  get %r{\A/redis\Z} do
    redis_search.search_with_text(params[:query], params[:ids] || 20, params[:offset] || 0).to_json
  end
  memory_changing_search = Search.new memory_changing_index
  get %r{\A/memory_changing\Z} do
    memory_changing_search.search_with_text(params[:query], params[:ids] || 20, params[:offset] || 0).to_json
  end
  redis_changing_search = Search.new redis_changing_index
  get %r{\A/redis_changing\Z} do
    redis_changing_search.search_with_text(params[:query], params[:ids] || 20, params[:offset] || 0).to_json
  end
  csv_test_search = Search.new csv_test_index, options
  get %r{\A/csv\Z} do
    csv_test_search.search_with_text(params[:query], params[:ids] || 20, params[:offset] || 0).to_json
  end
  isbn_search = Search.new isbn_index
  get %r{\A/isbn\Z} do
    isbn_search.search_with_text(params[:query], params[:ids] || 20, params[:offset] || 0).to_json
  end
  sym_keys_search = Search.new sym_keys_index
  get %r{\A/sym\Z} do
    sym_keys_search.search_with_text(params[:query], params[:ids] || 20, params[:offset] || 0).to_json
  end
  real_geo_search = Search.new real_geo_index
  get %r{\A/geo\Z} do
    real_geo_search.search_with_text(params[:query], params[:ids] || 20, params[:offset] || 0).to_json
  end
  mgeo_search = Search.new mgeo_index
  get %r{\A/simple_geo\Z} do
    mgeo_search.search_with_text(params[:query], params[:ids] || 20, params[:offset] || 0).to_json
  end
  iphone_search = Search.new iphone_locations
  get %r{\A/iphone\Z} do
    iphone_search.search_with_text(params[:query], params[:ids] || 20, params[:offset] || 0).to_json
  end
  indexing_search = Search.new indexing_index
  get %r{\A/indexing\Z} do
    indexing_search.search_with_text(params[:query], params[:ids] || 20, params[:offset] || 0).to_json
  end
  all_search = Search.new books_index, csv_test_index, isbn_index, mgeo_index, options
  get %r{\A/all\Z} do
    all_search.search_with_text(params[:query], params[:ids] || 20, params[:offset] || 0).to_json
  end

end