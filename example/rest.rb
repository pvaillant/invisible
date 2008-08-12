$: << File.join(File.dirname(__FILE__),"..","lib")
require "invisible"

require 'data_mapper'
require 'dm-serializer'

DataMapper.setup(:default, 'sqlite3:local.db')

class Product
  include DataMapper::Resource
  property :id, Integer, :serial => true
  property :name, String, :nullable => false
  property :description, Text
  property :sku, String, :nullable => false
  property :price, Float #, :precision => 2
end

DataMapper.auto_migrate!

Invisible.new do
  use Rack::CommonLogger
  rest :product
end.run
