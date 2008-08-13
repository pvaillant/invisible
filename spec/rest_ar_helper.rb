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