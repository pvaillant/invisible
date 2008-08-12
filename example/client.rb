require 'rubygems'
$:.unshift "/home/Paul/src/github/rails/activeresource/lib"
require 'activeresource'
require 'benchmark'

class Product < ActiveResource::Base
  self.site = "http://localhost:3000/"
end

attrs = {:name => "Chair", :sku => "chair1", :price => 23.45}
prod = Product.new(attrs)
p prod.save,prod,prod.errors.full_messages
exit

n = 100
recs = []
Benchmark.bm do |x|
  x.report("create") { n.times {recs << Product.create(attrs)} }
  x.report("read  ") { recs.each {|rec| Product.find(rec.id)} }
  x.report("list  ") { 10.times {Product.find(:all)} }
  x.report("update") { recs.each {|rec| rec.price = "9.99"; rec.save} }
  x.report("delete") { recs.each {|rec| rec.destroy} }
end
