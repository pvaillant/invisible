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