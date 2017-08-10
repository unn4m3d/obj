require "./src/obj"
require "benchmark"

file =  ARGV.first

File.open(file) do |f|
  parser = OBJ::OBJParser.new f, ARGV.size > 1

  begin
    puts "Parser v #{OBJ::VERSION}"
    puts Benchmark.measure {
      parser.parse!
    }
    puts "#{parser.mtllibs.size} mtllib(s)"
    puts "#{parser.faces.size} face(s)"
    puts "#{parser.vertices.size} vertice(s)"
    puts "#{parser.objects.size} object(s)"
    puts "#{parser.groups.size} group(s)"
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
