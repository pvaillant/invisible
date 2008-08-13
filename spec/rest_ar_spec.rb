require File.dirname(__FILE__) + "/spec_helper"

describe "REST ActiveRecords" do
  before do
    # this mocks the AR functions that rest uses
    class Aproduct
      @@data = {:name => "Chair", :price => "23.45"}

      def self.find(what)
        if what == :all
          [Aproduct.new(@@data.merge(:id => 1))]
        else
          Aproduct.new(@@data.merge(:id => what))
        end
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
        "<aproduct><id>#{@id}</id><name>#{@name}</name><price>#{@price}</price></aproduct>"
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
      rest :aproduct
    end
  end

  it "should return a list of products to GET /products.xml" do
    @app.mock.get("/aproducts.xml").body.should == "<aproducts type='array'><aproduct><id>1</id><name>Chair</name><price>23.45</price></aproduct></aproducts>"
  end

  it "should return a list of products to GET /products.js" do
    @app.mock.get("/aproducts.js").body.should == "[{ \"id\": 1, \"name\": \"Chair\", \"price\": 23.45 }]"
  end
  
  it "should return a product for GET /products/2.xml" do
    @app.mock.get("/aproducts/2.xml").body.should == "<aproduct><id>2</id><name>Chair</name><price>23.45</price></aproduct>"
  end
  
  it "should return a product for GET /products/2.js" do
    @app.mock.get("/aproducts/2.js").body.should == "{ \"id\": 2, \"name\": \"Chair\", \"price\": 23.45 }"
  end

  it "should return an updated product for PUT /products/2.xml" do
    xml = "<aproduct><id>2</id><name>Chair</name><price>9.99</price></aproduct>"
    opts = {'CONTENT_TYPE' => "application/xml", :input => xml}
    @app.mock.put("/aproducts/2.xml", opts).status.should == 204
  end
  
  it "should return an updated product for PUT /products/2.js" do
    json = "{product: {id: 2, name: 'Chair', price: 9.99}}"
    opts = {'CONTENT_TYPE' => "application/json", :input => json}
    @app.mock.put("/aproducts/2.js", opts).status.should == 204
  end

  it "should return a Location for a new product for POST /products.xml" do
    xml = "<aproduct><id>3</id><name>Chair</name><price>9.99</price></aproduct>"
    opts = {'CONTENT_TYPE' => "application/xml", :input => xml}
    response = @app.mock.post("/aproducts.xml", opts)
    response.status.should == 201
    response.headers['Location'].should == "http://example.org/aproducts/3.xml"
  end

  it "should return a Location for a new product for POST /products.js" do
    json = "{aproduct: {id: 3, name: 'Chair', price: 9.99}}"
    opts = {'CONTENT_TYPE' => "application/json", :input => json}
    response = @app.mock.post("/aproducts.js", opts)
    response.status.should == 201
    response.headers['Location'].should == "http://example.org/aproducts/3.js"
  end

  it "should return success for deleting product DELETE /products/2.xml" do
    @app.mock.delete("/aproducts/2.xml").status == 200
  end

  it "should return success for deleting product DELETE /products/2.js" do
    @app.mock.delete("/aproducts/2.js").status == 200
  end
end