require File.dirname(__FILE__) + "/spec_helper"

describe "params" do
  before do
    @app = Invisible.new do
      get "/" do
        render params.inspect
      end
      get "/:path" do
        render params.inspect
      end
    end
  end
  
  it "should include request params" do
    @app.mock.get("/?oh=aie").body.should == { 'oh' => 'aie' }.inspect
  end

  it "should include path params" do
    @app.mock.get("/oh").body.should == { 'path' => 'oh' }.inspect
  end
  
  it "should handle xml posts as params" do
    xml = "<product><name>Chair</name></product>"
    opts = {"CONTENT_TYPE" => "application/xml", :input => xml}
    @app.mock.get("/",opts).body.should == {'product' => {'name' => 'Chair'}}.inspect
  end

  it "should handle json posts as params" do
    json = "{product: {name: 'Chair'}}"
    opts = {"CONTENT_TYPE" => "application/json", :input => json}
    @app.mock.get("/",opts).body.should == {'product' => {'name' => 'Chair'}}.inspect
  end
end