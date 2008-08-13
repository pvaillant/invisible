require "rubygems"
require "thin"
require "markaby"
require "english/inflect"
require "invisible/core_ext"
require "yaml"

# = The Invisible framework class
# If Camping is a micro-framwork at 4K then Invisible is a pico-framework of 2K.
# Half the size mainly because of Rack. Many ideas were borrowed from Sinatra,
# but with a few more opinions on my own and a strong emphasis on compactness.
#
# == Build an app in an object
# Invisible supports multiple applications running in the same VM. Each instance
# of this class represents a runnable application.
#
#  app = Invisible.new do
#    get "/" do
#      render "ohaie"
#    end
#  end
#
# == Build an app in a file
# DSL like Sinatra is also supported, put all your `get`, `post`, `layout` in your
# naked file and Invisible will do the method_missing magic for you.
#
# == Your app is a Rack config file (or not)
# Often the problem with new frameworks is you have to find how to deploy it.
# You either can make your app file standalone and runnable on its own, put this
# at the end of your file:
# 
#  app.run
# 
# Or to use as a Rack config file, switch the 2 and remove the dot
# 
#  run app
# 
# Then you'll be able to run with Thin:
# 
#  thin start -R app.ru
# 
class Invisible
  HTTP_METHODS = [:get, :post, :head, :put, :delete]
  attr_reader :request, :response, :params
  
  # Creates a new Invisible Rack application. You can build your app
  # in the yielded block or using the app instance.
  def initialize(&block)
    @actions = []
    @with    = []
    @layouts = {}
    @views   = {}
    @helpers = Module.new
    @app     = Rack::Cascade.new([Rack::File.new("public"), method(:_call)])
    instance_eval(&block) if block
  end
  
  # Register an action for a specified +route+.
  # 
  #  get "/" do
  #    # ...
  #  end
  #
  def action(method, route, &block)
    @actions << [method.to_s, build_route(@with * "/" + route), block]
  end
  HTTP_METHODS.each { |m| class_eval "def #{m}(r='/',&b); action('#{m}', r, &b) end" }
  
  # Wrap actions sharing a common base route.
  #
  #  with "/lol" do
  #    get "/cat" # ...
  #  end
  #
  # Will register an action on GET /lol/cat.
  # You can nested as many level as you want.
  def with(route)
    @with.push(route)
    yield
    @with.pop
  end
  
  # Implements restful resource routes that are ActiveResource compatible
  # 
  # rest "product"
  # 
  # This method expects to find a class Product, and creates the following routes:
  # 
  # get "/products.:format"
  # get "/products/:id.:format"
  # post "/products.:format"
  # put "/products/:id.:format"
  # delete "/products/:id.:format"
  # 
  # see http://api.rubyonrails.org/files/vendor/rails/activeresource/README.html
  def rest(name,options = {})
    name = name.to_s.singular
    klass = nil
    begin
      klass_name = name.sub(/.*\./, '').gsub(/\/(.?)/) { "::" + $1.upcase }.gsub(/(^|_)(.)/) { $2.upcase }
      klass = eval klass_name
    rescue
      warn "Failed to resolve #{klass_name}"
      return
    end
    root = "/#{name.plural.downcase}"
    with root do
      get ".:format" do
        record(klass,:all)
      end
      get "/:id.:format" do
        record(klass,@path_params['id']) do |record|
          [200, record]
        end
      end
      post ".:format" do
        record(klass,:new,@params[name]) do |record|
          [201, '', {'Location' => "#{@request.scheme}://#{@request.host}#{root}/#{record.id}.#{@path_params['format']}"}]
        end
      end unless options[:readonly]
      put "/:id.:format" do
        record(klass,@path_params['id'],@params[name]) do |record|
          [204, ''] # the docs say this should be empty, but the client bombs if it's empty
        end
      end unless options[:readonly]
      delete "/:id.:format" do
        record(klass,@path_params['id'],:destroy) do
          [200, '']
        end
      end unless options[:readonly]
    end
  end  
  
  # Render the response inside an action.
  # Render markaby by passing a block:
  #
  #  render do
  #    h1 "Poop"
  #    p "Smells!"
  #  end
  # 
  # or simple text as the first argument.
  # 
  #  render "crap"
  #
  # You can also pass some option or headers:
  #
  #  render "heck", :status => 201, :layout => :none, 'X-Crap-Level' => 'ubersome'
  #
  def render(*args, &block)
    options = args.last.is_a?(Hash) ? args.pop : {}
    @response.status = options.delete(:status) || 200
    layout  = @layouts[options.delete(:layout) || :default]
    assigns = { :request => request, :response => response, :params => params, :session => session }
    content = args.last.is_a?(String) ? args.last : Markaby::Builder.new(assigns, @helpers, &(block || @views[args.last])).to_s
    content = Markaby::Builder.new(assigns.merge(:content => content), @helpers, &layout).to_s if layout
    @response.headers.merge!(options)
    @response.body = content
  end
  
  # Register a layout to be used around +render+ed text.
  # Use markaby inside your block.
  def layout(name=:default, &block)
    @layouts[name] = block
  end
  
  # Register a named view to be used from <tt>render :name</tt>.
  # Use markaby inside your block.
  def view(name, &block)
    @views[name] = block
  end
  
  # Define helper methods to be used inside the actions and inside
  # the views.
  # Inside markaby, helpers are added to the @helpers object:
  #
  #  my_helper
  #  render do
  #    @helpers.my_helper
  #  end
  #
  def helpers(&block)
    @helpers.instance_eval(&block)
    instance_eval(&block)
  end
  
  # Return the current session.
  # Add `use Rack::Session::Cookie` to use.
  def session
    @request.env["rack.session"]
  end
  
  # Register a Rack middleware wrapping the
  # current application.
  def use(middleware, *args)
    @app = middleware.new(@app, *args)
  end
  
  # Run the application using Thin.
  # All arguments are passed to Thin::Server.start.
  def run(*args)
    Thin::Server.start(@app, *args)
  end
  
  # Called by the Rack handler to process a request.
  def call(env)
    @app.call(env)
  end
  
  # Allow to defined and run an application in a single call.
  def self.run(*args, &block)
    new(&block).run(*args)
  end
  
  def self.app
    @app ||= self.new
  end
  
  def self.call(env)
    @app.call(env)
  end
  
  private
    def record(klass, id = :new, data = nil)
      # this supports datamapper and activerecord models
      code,body,hdrs = begin
        if id == :all
          list = (klass.respond_to?(:all) ? klass.all : klass.find(:all))
          [200, list]
        else
          rec = if id == :new
            klass.new
          else
            (klass.respond_to?(:get) ? klass.get(id.to_i) : klass.find(id.to_i))
          end
          if rec
            if data
              op = if data == :destroy
                :destroy
              else
                rec.attributes = data
                :save
              end
              if rec.send(op)
                yield rec
              else
                [422, rec.errors.full_messages]
              end
            else
              yield rec
            end
          else
            [404, 'Record Not Found']
          end
        end
      rescue Exception => ex
        [500, ex.message]
      end
      hdrs ||= {}
      if String === body
        hdrs.merge!("Content-Length" => "0") if body.size == 0
        hdrs.merge!("Content-Type" => "text/plain")
      elsif Array === body && code/100 == 4 # these are error messages
        if @path_params['format'] == 'xml'
          hdrs.merge!("Content-Type" => "text/xml")
          # NOTE: the docs say it should have type="array" on errors, but that's not right
          body = "<errors>" + body.map {|err| "<error>#{err}</error>"}.join("") + "</errors>"
        elsif @path_params['format'] == 'js'
          hdrs.merge!("Content-Type" => "text/javascript")
          # TODO: what should the format actually be?
          body = "{errors: ['" + body.join("','") + "']}"
        else
          code = 400
          hdrs = {'Content-Type' => "text/plain"}
          body = "Unsupported format #{@path_params['format']}"
        end
      else
        if @path_params['format'] == 'xml'
          hdrs.merge!("Content-Type" => "text/xml")
          if Array === body
            root = klass.to_s.gsub(/::/, '/').gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
              gsub(/([a-z\d])([A-Z])/,'\1_\2').tr("-", "_").downcase.plural
            body = "<#{root} type='array'>" + body.map {|x| x.to_xml}.join("") + "</#{root}>"
          else
            body = body.to_xml
          end
        elsif @path_params['format'] == 'js'
          hdrs.merge!("Content-Type" => "text/javascript")
          if Array === body
            body = "[" + body.map {|x| x.to_json}.join(",") + "]"
          else
            body = body.to_json
          end
        else
          code = 400
          hdrs = {'Content-Type' => "text/plain"}
          body = "Unsupported format #{@path_params['format']}"
        end
      end
      @response = Rack::Response.new(body,code,hdrs)
    end
    
    def _call(env)
      @request  = Rack::Request.new(env)
      @response = Rack::Response.new
      if env["CONTENT_TYPE"] == "application/xml"
        @params = Hash.from_xml(@request.env["rack.input"]) rescue {}
      elsif env["CONTENT_TYPE"] == "application/json"
        # JSON is basically close enough to YAML that this should work 99% of the time
        # see http://redhanded.hobix.com/inspect/jsonCloserToYamlButNoCigarThanksAlotWhitespace.html
        @params = YAML.load(@request.env["rack.input"]) rescue {}
      else
        @params = @request.params
      end
      if action = recognize(env["PATH_INFO"], @params["_method"] || env["REQUEST_METHOD"])
        @params.merge!(@path_params)
        action.last.call
        @response.finish
      else
        [404, {}, "Not found"]
      end
    end
    
    def build_route(route)
      # NOTE: this builds routes slightly differently then the main invisible
      # it only allows [a-z] in param names, but supports format extensions
      # ex /products/:id.xml is valid with this code, but not the main build_route
      pattern = '\/*' + route.gsub("/",'\/*').gsub(/:[a-z]+/,'(\w+)') + '\/*'
      [/^#{pattern}$/i, route.scan(/\:([a-z]+)/).flatten]
    end
    
    def recognize(url, method)
      method = method.to_s.downcase
      @actions.detect do |m, (pattern, keys), _|
        method == m && @path_params = match_route(pattern, keys, url)
      end
    end
    
    def match_route(pattern, keys, url)
      matches, params = (url.match(pattern) || return)[1..-1], {}
      keys.each_with_index { |key, i| params[key] = matches[i] }
      params
    end
end

def method_missing(method, *args, &block)
  if Invisible.app.respond_to?(method)
    Invisible.app.send(method, *args, &block)
  else
    super
  end
end
