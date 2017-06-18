require "./spec_helper"

describe OBJ do
  # TODO: Write tests

  it "works" do
    File.open("#{__DIR__}/../cornell_box.obj") do |f|
      parser = OBJ::OBJParser.new f
      parser.parse!
      parser.objects.size.should eq(10)
    end
  end
end
