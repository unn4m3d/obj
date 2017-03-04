require "crystaledge"

module OBJ
  class Vertex
    property coord : CrystalEdge::Vector3
    property normal : CrystalEdge::Vector3?
    property texcoord : CrystalEdge::Vector3?

    def initialize(
                   @coord = CrystalEdge::Vector3.zero,
                   @normal = CrystalEdge::Vector3.zero,
                   @texcoord = CrystalEdge::Vector3.zero)
    end
  end

  class Face
    property vertices = [] of Vertex
    property material : String

    def initialize(@vertices, @material)
    end
  end

  class NamedObject
    property name : String
    property faces = [] of Face
    property mtl : String
    property groups = [] of Group

    def initialize(@name, @faces, @mtl, @groups)
    end
  end

  class Group
    property name : String
    property faces = [] of Face
    property mtl : String

    def initialize(@name, @faces, @mtl)
    end
  end

  class ParserBase
    @directives = {} of String => String ->

    def on(tag, &proc : String ->)
      @directives[tag.to_s] = proc
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

    def parse!
      line_num = 1
      while line = @io.gets
        line = line.split("#", 2).first
        unless @directives.keys.any? { |x| line.includes? x }
          if line.match(/[a-zA-Z0-9]/)
            warn "Skipping unknown directive #{line.split(/\s/, 2).first}"
          end
          line_num += 1
          next
        end
        name = pull_string! line
        line = line[name.size + 1..-1].gsub(/^\s+/, "")
        if @directives.has_key? name
          begin
            @directives[name].call(line)
          rescue e : Exception
            raise Exception.new("Cannot parse line #{line_num}", e)
          end
        else
          raise "Invalid directive #{name} at line #{line_num} "
        end
        line_num += 1
      end
      @directives["$eof"].call("$eof")
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

    property faces, mtllibs, faces, groups, objects

    def vertices
      @vcoords
    end

    def vertices=(v)
      @vcoords = v
    end

    def initialize(@io)
      @current_mtl = ""
      @gindex = 0i32
      @oindex = 0i32
      @ogindex = 0i32

      on :mtllib do |str|
        @mtllibs << str
      end

      on :usemtl do |str|
        @current_mtl = str
      end

      on :v do |str|
        numbers = str.split(/\s+/, 3).map &.to_f64
        @vcoords << CrystalEdge::Vector3.new(*Tuple(FloatT, FloatT, FloatT).from(numbers))
      end

      on :vt do |str|
        numbers = str.split(/\s+/, 3).map &.to_f64
        @tcoords << CrystalEdge::Vector3.new(*Tuple(FloatT, FloatT, FloatT).from(numbers))
      end

      on :vn do |str|
        numbers = str.split(/\s+/, 3).map &.to_f64
        @normals << CrystalEdge::Vector3.new(*Tuple(FloatT, FloatT, FloatT).from(numbers))
      end

      on :f do |str|
        @faces << Face.new(str.scan(/(?<vert>[\-0-9]+)(\/(?<tex>[\-0-9]+)?(\/(?<norm>[\-0-9]+))?)?/).map do |scan|
          tc, nc = scan["tex"]?, scan["norm"]?

          Vertex.new(
            @vcoords[tr_num scan["vert"].to_i],
            (tc ? @tcoords[tr_num tc.to_i]? : nil),
            (nc ? @normals[tr_num nc.to_i]? : nil)
          )
        end, @current_mtl)
      end

      on :o do |str|
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
        @objects[@current_obj.to_s] = NamedObject.new(@current_obj.to_s, faces, @current_mtl, groups)
        @current_obj = str
      end

      on :g do |str|
        faces = if @gindex < @faces.size
                  @faces.skip(@gindex)
                else
                  [] of Face
                end
        @gindex = @faces.size
        @groups << Group.new(@current_group || "$rootgroup", faces, @current_mtl)
        @current_group = str
      end

      on :"$eof" do |str|
        @directives["o"].call "$eof"
        @directives["g"].call "$eof"
      end
    end

    alias FloatT = Float64

    protected def tr_num(f)
      f <= 0 ? f : f - 1
    end

    def debug!(io : IO)
      {% for var in @type.instance_vars %}
        puts "{{var}} = #{@{{var}}}"
      {% end %}
    end
  end
end
