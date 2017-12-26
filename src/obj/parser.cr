require "crystaledge"
require "models"

module OBJ
  alias Vertex = Models::Vertex

  alias Face = Models::Face

  alias NamedObject = Models::Shape

  alias Group = Models::Shape

  class ParserBase
    @directives = {} of (Regex|String) => String, String ->
    @line_num = 0u64
    property custom_file_opener : Proc(String, IO)? = nil

    def on(tag : String | Symbol, &proc : String, String ->)
      @directives[tag.to_s] = ->(cmd : String, line : String){
        proc.call cmd, line
      }
    end

    def on(r : Regex, &proc : String, String ->)
      @directives[r] = proc
    end

    @wcb = ->(s : String) {
      STDERR.puts "WARNING : #{s}"
    }

    def on_warning(&proc : String ->)
      @wcb = proc
    end

    def warn(s)
      @wcb.call(s)
    end

    protected def pull_string!(str)
      parts = str.split(/\s/, 2)
      str = parts.first
      while parts.first.ends_with? "\\"
        parts = parts.last.split(/\s/, 2)
        str = str.gsub(/\\$/, "") + " " + parts.first
      end
      str
    end

    protected def dir!(name, line) : Void
      if @directives.has_key? name
        @directives[name].call name, line
        return
      end
      dirs = @directives.select{|k,v| k === name}
      raise "Invalid directive #{name} at line #{@line_num}" if dirs.empty?
      begin
        dirs.each_value &.call name, line
      rescue e : Exception
        raise Exception.new("Cannot parse line #{@line_num} : #{e.message}", e)
      end
    end

    def parse!
      @line_num = 1
      while line = @io.gets
        line = line.partition('#').first
        if line.delete(" \t\r\n").empty?
          @line_num += 1
          next
        end
        parts = line.partition(/\s+/)
        dir = parts.first
        dir! dir, parts.last
        @line_num += 1
      end
      dir! "$eof", "$eof"
    end

    def open_file(file)
      if @custom_file_opener
        @custom_file_opener.not_nil!.call file
      else
        File.open file
      end
    end

    def open_file(file, &block : IO->)
      handler = open_file file
      begin
        block.call handler
      ensure
        handler.close
      end
    end
  end

  class OBJParser < ParserBase
    @io : IO
    @current_mtl : String
    @vcoords = [] of CrystalEdge::Vector3
    @tcoords = [] of CrystalEdge::Vector3
    @normals = [] of CrystalEdge::Vector3
    @mtllibs = [] of String
    @faces = [] of Face
    @gindex : Int32
    @oindex : Int32
    @current_obj : String? = nil
    @current_group : String? = nil
    @groups = [] of Group
    @ogindex : Int32
    @objects = {} of String => NamedObject
    @filename : String

    @triangulate : Bool
    @load_materials : Bool

    @materials = {} of String => Material

    property mtllibs, faces, groups, objects, materials

    def vertices
      @vcoords
    end

    def vertices=(v)
      @vcoords = v
    end

    def current_mtl
      if @materials.has_key? @current_mtl
        @materials[@current_mtl]
      else
        mat = Material.new @current_mtl
        @materials[@current_mtl] = mat unless @current_mtl.empty?
        mat
      end
    end

    def initialize(@io, @filename, @triangulate = false, @load_materials = true)
      @current_mtl = ""
      @gindex = 0i32
      @oindex = 0i32
      @ogindex = 0i32

      on :mtllib do |c, str|
        @mtllibs << str
        if @load_materials
          path = File.join(File.dirname(@filename), str)
          if File.exists? path
            open_file path do |f|
              parser = MTLParser.new f
              parser.custom_file_opener = @custom_file_opener
              parser.on_warning do |w|
                warn w
              end
              parser.parse!
              @materials.merge! parser.mtls
            end
          end
        end
      end

      on :usemtl do |c, str|
        @current_mtl = str
      end

      on :v do |c, str|
        numbers = str.split(/\s+/, 3).map &.to_f64
        @vcoords << CrystalEdge::Vector3.new(*Tuple(FloatT, FloatT, FloatT).from(numbers))
      end

      on :vt do |c, str|
        numbers = str.split(/\s+/, 3).map &.to_f64
        numbers << 0.0 if numbers.size < 3
        @tcoords << CrystalEdge::Vector3.new(*Tuple(FloatT, FloatT, FloatT).from(numbers))
      end

      on :vn do |c, str|
        numbers = str.split(/\s+/, 3).map &.to_f64
        @normals << CrystalEdge::Vector3.new(*Tuple(FloatT, FloatT, FloatT).from(numbers))
      end

      on :f do |c, str|
        face = str.scan(/(?<vert>[\-0-9]+)(\/(?<tex>[\-0-9]+)?(\/(?<norm>[\-0-9]+))?)?/).map do |scan|
          tc, nc = scan["tex"]?, scan["norm"]?

          Vertex.new(
            @vcoords[tr_num scan["vert"].to_i],
            (tc ? @tcoords[tr_num tc.to_i]? : nil),
            (nc ? @normals[tr_num nc.to_i]? : nil)
          )
        end

        if @triangulate && face.size > 3
          triangles = face.size - 2

          first = face.first

          triangles.times do |i|
            @faces << [
              first,
              face[1 + i],
              face[2 + i]
            ]
          end
        else
          @faces << face
        end
      end

      on :o do |c, str|
        groups = if @ogindex < @groups.size
                   @groups.skip(@ogindex)
                 else
                   [] of Group
                 end
        faces = if @oindex < @faces.size
                  @faces.skip(@oindex)
                else
                  [] of Face
                end
        @ogindex = @groups.size
        @oindex = @faces.size
        @current_obj ||= "$root"
        @objects[@current_obj.to_s] = NamedObject.new(
          @current_obj.to_s,
          faces,
          current_mtl,
          groups
        )
        @current_obj = str
      end

      on :g do |c, str|
        faces = if @gindex < @faces.size
                  @faces.skip(@gindex)
                else
                  [] of Face
                end
        @gindex = @faces.size
        @groups << Group.new(
          @current_group || "$rootgroup",
          faces,
          current_mtl,
          [] of Models::Shape
        )
        @current_group = str
      end

      on :"$eof" do |c, s|
        dir! "o", s
        dir! "g", s
      end
    end

    alias FloatT = Float64

    protected def tr_num(f)
      f <= 0 ? f : f - 1
    end

    def debug!(io : IO)
      {% for var in @type.instance_vars %}
        io.puts "{{var}} = #{@{{var}}}"
      {% end %}
    end
  end

  alias Material = Models::Material

  class MTLParser < ParserBase
    @current_mtl = "$default"
    @mtls = {} of String => Material
    @io : IO



    property mtls

    protected def check_mtl!
      if @mtls.has_key? @current_mtl
        @mtls[@current_mtl]
      else
        @mtls[@current_mtl] = Material.new(@current_mtl)
      end
    end

    def initialize(@io)
      on "newmtl" do |cmd, rest|
        @current_mtl = rest.strip
        check_mtl!
      end

      on "$eof" { |c, r| }

      on /^K./ do |cmd, rest|
        check_mtl!
        r, g, b = rest.split(/\s+/).map &.to_f64
        @mtls[@current_mtl].colors[cmd] = CrystalEdge::Vector3.new(r, g, b)
      end

      on /^map_.*/ do |cmd, rest|
        check_mtl!
        name = cmd[4..-1]
        @mtls[@current_mtl].maps[name] = rest
      end

      on "d" do |_, rest|
        @mtls[@current_mtl].dissolvance = rest.chomp.to_f64
      end

      on "Tr" do |_, rest|
        @mtls[@current_mtl].dissolvance = 1.0 - rest.chomp.to_f64
      end
    end
  end
end
