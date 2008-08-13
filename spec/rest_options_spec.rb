require File.dirname(__FILE__) + "/spec_helper"
require File.dirname(__FILE__) + "/rest_dm_helper"

describe "REST Options" do
  before do
    @app = Invisible.new do
      rest :dproduct, :readonly => true
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
  
  it "should prevent an updated product for PUT /products/2.xml" do
    xml = "<dproduct><id>2</id><name>Chair</name><price>9.99</price></dproduct>"
    opts = {'CONTENT_TYPE' => "application/xml", :input => xml}
    @app.mock.put("/dproducts/2.xml", opts).status.should == 404
  end

  it "should prevent an updated product for PUT /products/2.js" do
    json = "{dproduct: {id: 2, name: 'Chair', price: 9.99}}"
    opts = {'CONTENT_TYPE' => "application/json", :input => json}
    @app.mock.put("/dproducts/2.js", opts).status.should == 404
  end

  it "should not return a Location for a new product for POST /products.xml" do
    xml = "<dproduct><id>3</id><name>Chair</name><price>9.99</price></dproduct>"
    opts = {'CONTENT_TYPE' => "application/xml", :input => xml}
    response = @app.mock.post("/dproducts.xml", opts)
    response.status.should == 404
    response.headers['Location'].should_not == "http://example.org/dproducts/3.xml"
  end

  it "should not return a Location for a new product for POST /products.js" do
    json = "{dproduct: {id: 3, name: 'Chair', price: 9.99}}"
    opts = {'CONTENT_TYPE' => "application/json", :input => json}
    response = @app.mock.post("/dproducts.js", opts)
    response.status.should == 404
    response.headers['Location'].should_not == "http://example.org/dproducts/3.js"
  end

  it "should prevent success for deleting product DELETE /products/2.xml" do
    @app.mock.delete("/dproducts/2.xml").status == 404
  end

  it "should prevent success for deleting product DELETE /products/2.js" do
    @app.mock.delete("/dproducts/2.js").status == 404
  end
end