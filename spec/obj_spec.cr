require "./spec_helper"

FILENAME = "#{__DIR__}/../cornell_box.obj"

describe OBJ do
  it "works" do
    File.open(FILENAME) do |f|
      parser = OBJ::OBJParser.new f, FILENAME, true
      parser.parse!
      parser.objects.size.should eq(10)
      parser.faces.each &.size.should eq(3)
    end
  end

  it "triangulates faces" do
    File.open(FILENAME) do |f|
      parser = OBJ::OBJParser.new f, FILENAME, true
      parser.parse!
      parser.faces.each &.size.should eq(3)
    end
  end

  it "loads materials" do
    File.open(FILENAME) do |f|
      parser = OBJ::OBJParser.new f, FILENAME, true
      parser.parse!
      parser.materials.keys.should eq(%w(white red green blue light))

      parser.materials["white"].colors["Kd"].x.should eq(1.0)
      parser.materials["light"].colors["Ka"].z.should eq(20.0)
    end
  end
end
