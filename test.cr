require "./src/obj"
require "benchmark"

file =  ARGV.first

File.open(file) do |f|
  parser = OBJ::OBJParser.new f, ARGV.size > 1

  begin
    puts Benchmark.measure {
      parser.parse!
    }
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
