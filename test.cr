require "./src/obj"

File.open("cornell_box.obj") do |f|
  parser = OBJ::OBJParser.new f

  begin
    parser.parse!
    puts "#{parser.mtllibs.size} mtllibs"
    puts "#{parser.faces.size} faces"
    puts "#{parser.vertices.size} vertices"
    puts "#{parser.objects.size} objects"
    puts "#{parser.groups.size} groups"
  rescue e : Exception
    parser.debug!(STDOUT)
    puts e
    puts e.backtrace.join("\n")
    unless e.cause.nil?
      puts e.cause
      puts e.cause.not_nil!.backtrace.join("\n")
    end
  end
end
