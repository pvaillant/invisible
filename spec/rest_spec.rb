require File.dirname(__FILE__) + "/spec_helper"

describe "REST" do
  before do
    # this mocks the DM functions that rest uses
    class Product
      @@data = {:name => "Chair", :price => "23.45"}
      class Collection
        def initialize(*list)
          @list = list
        end
        def to_xml
          "<products>" + @list.map {|prod| prod.to_xml}.join("") + "</products>"
        end
      end
      
      def self.all
        Product::Collection.new(Product.new(@@data.merge(:id => 1)))
      end
      
      def self.get(id)
        return Product.new(@@data.merge(:id => id))
      end
      
      attr_accessor :id, :name, :price
      def initialize(attrs = {})
        self.attributes = attrs
      end
      
      def attributes=(attrs)
        @id = attrs['id'] || attrs[:id]
        @name = attrs['name'] || attrs[:name]
        @price = attrs['price'] || attrs[:price]
      end
      
      def to_xml
        "<product><id>#{@id}</id><name>#{@name}</name><price>#{@price}</price></product>"
      end

      def save
        return true
      end
      
      def destroy
        return true
      end
    end
    
    @app = Invisible.new do
      get "/" do
        render "get it?"
      end
      
      post "/" do
        render "post it?"
      end

      put "/" do
        render "put it?"
      end

      delete "/" do
        render "delete it?"
      end
      
      rest :product
    end
  end
  
  it "should respond to GET /" do
    @app.mock.get("/").body.should == "get it?"
  end

  it "should respond to POST /" do
    @app.mock.post("/").body.should == "post it?"
  end

  it "should respond to PUT /" do
    @app.mock.put("/").body.should == "put it?"
  end

  it "should respond to DELETE /" do
    @app.mock.delete("/").body.should == "delete it?"
  end
  
  it "should use _method request param" do
    @app.mock.post("/?_method=put").body.should == "put it?"
  end

  it "should use _method form param" do
    @app.mock.post("/", :input => "_method=put").body.should == "put it?"
  end
  
  it "should return a list of products to GET /products.xml" do
    @app.mock.get("/products.xml").body.should == "<products><product><id>1</id><name>Chair</name><price>23.45</price></product></products>"
  end

  it "should return a product for GET /products/2.xml" do
    @app.mock.get("/products/2.xml").body.should == "<product><id>2</id><name>Chair</name><price>23.45</price></product>"
  end

  it "should return an updated product for PUT /products/2.xml" do
    xml = "<product><id>2</id><name>Chair</name><price>9.99</price></product>"
    opts = {'CONTENT_TYPE' => "application/xml", :input => xml}
    @app.mock.put("/products/2.xml", opts).status.should == 204
  end

  it "should return a Location for a new product for POST /products.xml" do
    xml = "<product><id>3</id><name>Chair</name><price>9.99</price></product>"
    opts = {'CONTENT_TYPE' => "application/xml", :input => xml}
    response = @app.mock.post("/products.xml", opts)
    response.status.should == 201
    response.headers['Location'].should == "http://example.org/products/3.xml"
  end

  
  it "should return success for deleting product DELETE /products/2.xml" do
    @app.mock.delete("/products/2.xml").status == 200
  end
end