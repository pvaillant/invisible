require File.dirname(__FILE__) + "/spec_helper"

describe "REST DataMapper" do
  before do
    # this mocks the DM functions that rest uses
    class Dproduct
      @@data = {:name => "Chair", :price => "23.45"}
      class Collection
        def initialize(*list)
          @list = list
        end
        def to_xml
          "<dproducts type='array'>" + @list.map {|prod| prod.to_xml}.join("") + "</dproducts>"
        end
        def to_json
          "[" + @list.map {|prod| prod.to_json}.join(",") + "]"
        end
      end
      
      def self.all
        Dproduct::Collection.new(Dproduct.new(@@data.merge(:id => 1)))
      end
      
      def self.get(id)
        return Dproduct.new(@@data.merge(:id => id))
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
        "<dproduct><id>#{@id}</id><name>#{@name}</name><price>#{@price}</price></dproduct>"
      end
      
      def to_json
        "{ \"id\": #{@id}, \"name\": \"#{@name}\", \"price\": #{@price} }"
      end

      def save
        return true
      end
      
      def destroy
        return true
      end
    end
    
    @app = Invisible.new do
      rest :dproduct
    end
  end

  it "should return a list of products to GET /products.xml" do
    @app.mock.get("/dproducts.xml").body.should == "<dproducts type='array'><dproduct><id>1</id><name>Chair</name><price>23.45</price></dproduct></dproducts>"
  end

  it "should return a list of products to GET /products.js" do
    @app.mock.get("/dproducts.js").body.should == "[{ \"id\": 1, \"name\": \"Chair\", \"price\": 23.45 }]"
  end
  
  it "should return a product for GET /products/2.xml" do
    @app.mock.get("/dproducts/2.xml").body.should == "<dproduct><id>2</id><name>Chair</name><price>23.45</price></dproduct>"
  end

  it "should return a product for GET /products/2.js" do
    @app.mock.get("/dproducts/2.js").body.should == "{ \"id\": 2, \"name\": \"Chair\", \"price\": 23.45 }"
  end
  
  it "should return an updated product for PUT /products/2.xml" do
    xml = "<dproduct><id>2</id><name>Chair</name><price>9.99</price></dproduct>"
    opts = {'CONTENT_TYPE' => "application/xml", :input => xml}
    @app.mock.put("/dproducts/2.xml", opts).status.should == 204
  end

  it "should return an updated product for PUT /products/2.js" do
    json = "{dproduct: {id: 2, name: 'Chair', price: 9.99}}"
    opts = {'CONTENT_TYPE' => "application/json", :input => json}
    @app.mock.put("/dproducts/2.js", opts).status.should == 204
  end

  it "should return a Location for a new product for POST /products.xml" do
    xml = "<dproduct><id>3</id><name>Chair</name><price>9.99</price></dproduct>"
    opts = {'CONTENT_TYPE' => "application/xml", :input => xml}
    response = @app.mock.post("/dproducts.xml", opts)
    response.status.should == 201
    response.headers['Location'].should == "http://example.org/dproducts/3.xml"
  end

  it "should return a Location for a new product for POST /products.js" do
    json = "{dproduct: {id: 3, name: 'Chair', price: 9.99}}"
    opts = {'CONTENT_TYPE' => "application/json", :input => json}
    response = @app.mock.post("/dproducts.js", opts)
    response.status.should == 201
    response.headers['Location'].should == "http://example.org/dproducts/3.js"
  end

  it "should return success for deleting product DELETE /products/2.xml" do
    @app.mock.delete("/dproducts/2.xml").status == 200
  end

  it "should return success for deleting product DELETE /products/2.js" do
    @app.mock.delete("/dproducts/2.js").status == 200
  end
end