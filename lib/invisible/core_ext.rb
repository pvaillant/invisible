# from merb-core core_ext.rb
# ??? is there another facets-like library that might have these?
# this provides the ability to parse XML into Hashes
# all submitted data is XML currently

class Class
  def cattr_reader(*syms)
    syms.flatten.each do |sym|
      next if sym.is_a?(Hash)
      class_eval(<<-RUBY, __FILE__, __LINE__ + 1)
        unless defined? @@#{sym}
          @@#{sym} = nil
        end

        def self.#{sym}
          @@#{sym}
        end

        def #{sym}
          @@#{sym}
        end
      RUBY
    end
  end
  def cattr_writer(*syms)
    options = syms.last.is_a?(Hash) ? syms.pop : {}
    syms.flatten.each do |sym|
      class_eval(<<-RUBY, __FILE__, __LINE__ + 1)
        unless defined? @@#{sym}
          @@#{sym} = nil
        end

        def self.#{sym}=(obj)
          @@#{sym} = obj
        end
      RUBY

      unless options[:instance_writer] == false
        class_eval(<<-RUBY, __FILE__, __LINE__ + 1)
          def #{sym}=(obj)
            @@#{sym} = obj
          end
        RUBY
      end
    end
  end
  def cattr_accessor(*syms)
    cattr_reader(*syms)
    cattr_writer(*syms)
  end
end

class Hash
  class << self
    def from_xml( xml )
      ToHashParser.from_xml(xml)
    end
  end
end

require 'rexml/parsers/streamparser'
require 'rexml/parsers/baseparser'
require 'rexml/light/node'

# This is a slighly modified version of the XMLUtilityNode from
# http://merb.devjavu.com/projects/merb/ticket/95 (has.sox@gmail.com)
# It's mainly just adding vowels, as I ht cd wth n vwls :)
# This represents the hard part of the work, all I did was change the
# underlying parser.
class REXMLUtilityNode
  attr_accessor :name, :attributes, :children, :type
  cattr_accessor :typecasts, :available_typecasts

  self.typecasts = {}
  self.typecasts["integer"]       = lambda{|v| v.nil? ? nil : v.to_i}
  self.typecasts["boolean"]       = lambda{|v| v.nil? ? nil : (v.strip != "false")}
  self.typecasts["datetime"]      = lambda{|v| v.nil? ? nil : Time.parse(v).utc}
  self.typecasts["date"]          = lambda{|v| v.nil? ? nil : Date.parse(v)}
  self.typecasts["dateTime"]      = lambda{|v| v.nil? ? nil : Time.parse(v).utc}
  self.typecasts["decimal"]       = lambda{|v| BigDecimal(v)}
  self.typecasts["double"]        = lambda{|v| v.nil? ? nil : v.to_f}
  self.typecasts["float"]         = lambda{|v| v.nil? ? nil : v.to_f}
  self.typecasts["symbol"]        = lambda{|v| v.to_sym}
  self.typecasts["string"]        = lambda{|v| v.to_s}
  self.typecasts["yaml"]          = lambda{|v| v.nil? ? nil : YAML.load(v)}
  self.typecasts["base64Binary"]  = lambda{|v| Base64.decode64(v)}

  self.available_typecasts = self.typecasts.keys

  def initialize(name, attributes = {})
    @name         = name.tr("-", "_")
    @type         = self.class.available_typecasts.include?(attributes["type"]) ? attributes.delete("type") : attributes["type"]

    @nil_element  = attributes.delete("nil") == "true"
    @attributes   = undasherize_keys(attributes)
    @children     = []
    @text         = false
  end

  def add_node(node)
    @text = true if node.is_a? String
    @children << node
  end

  def to_hash
    if @type == "file"
      f = StringIO.new(::Base64.decode64(@children.first || ""))
      class << f
        attr_accessor :original_filename, :content_type
      end
      f.original_filename = attributes['name'] || 'untitled'
      f.content_type = attributes['content_type'] || 'application/octet-stream'
      return {name => f}
    end

    if @text
      return { name => typecast_value( translate_xml_entities( inner_html ) ) }
    else
      #change repeating groups into an array
      groups = @children.inject({}) { |s,e| (s[e.name] ||= []) << e; s }

      out = nil
      if @type == "array"
        out = []
        groups.each do |k, v|
          if v.size == 1
            out << v.first.to_hash.entries.first.last
          else
            out << v.map{|e| e.to_hash[k]}
          end
        end
        out = out.flatten

      else # If Hash
        out = {}
        groups.each do |k,v|
          if v.size == 1
            out.merge!(v.first)
          else
            out.merge!( k => v.map{|e| e.to_hash[k]})
          end
        end
        out.merge! attributes unless attributes.empty?
        out = out.empty? ? nil : out
      end

      if @type && out.nil?
        { name => typecast_value(out) }
      else
        { name => out }
      end
    end
  end
  def typecast_value(value)
    return value unless @type
    proc = self.class.typecasts[@type]
    proc.nil? ? value : proc.call(value)
  end

  # Convert basic XML entities into their literal values.
  #
  # @param value<#gsub> An XML fragment.
  #
  # @return <#gsub> The XML fragment after converting entities.
  def translate_xml_entities(value)
    value.gsub(/&lt;/,   "<").
      gsub(/&gt;/,   ">").
      gsub(/&quot;/, '"').
      gsub(/&apos;/, "'").
      gsub(/&amp;/,  "&")
  end

  # Take keys of the form foo-bar and convert them to foo_bar
  def undasherize_keys(params)
    params.keys.each do |key, value|
      params[key.tr("-", "_")] = params.delete(key)
    end
    params
  end

  # Get the inner_html of the REXML node.
  def inner_html
    @children.join
  end

  # Converts the node into a readable HTML node.
  #
  # @return <String> The HTML node in text form.
  def to_html
    attributes.merge!(:type => @type ) if @type
    "<#{name}#{attributes.to_xml_attributes}>#{@nil_element ? '' : inner_html}</#{name}>"
  end

  # @alias #to_html #to_s
  def to_s
    to_html
  end
end

class ToHashParser
  def self.from_xml(xml)
    stack = []
    parser = REXML::Parsers::BaseParser.new(xml)

    while true
      event = parser.pull
      case event[0]
      when :end_document
        break
      when :end_doctype, :start_doctype
        # do nothing
      when :start_element
        stack.push REXMLUtilityNode.new(event[1], event[2])
      when :end_element
        if stack.size > 1
          temp = stack.pop
          stack.last.add_node(temp)
        end
      when :text, :cdata
        stack.last.add_node(event[1]) unless event[1].strip.length == 0
      end
    end
    stack.pop.to_hash
  end
end
