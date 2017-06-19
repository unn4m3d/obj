require "./spec_helper"

describe OBJ do
  # TODO: Write tests

  it "works" do
    File.open("#{__DIR__}/../cornell_box.obj") do |f|
      parser = OBJ::OBJParser.new f, true
      parser.parse!
      parser.objects.size.should eq(10)
      parser.faces.each &.size.should eq(3)
    end
  end

  it "triangulates faces" do
    File.open("#{__DIR__}/../cornell_box.obj") do |f|
      parser = OBJ::OBJParser.new f, true
      parser.parse!
      parser.faces.each &.size.should eq(3)
    end
  end
end
