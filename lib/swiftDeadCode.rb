require 'yaml'
require 'pathname'
require 'set'

module SwiftDeadCode

    class SwiftDepsModel
        attr_accessor :fileName, :provides, :nominals, :depends, :realDeps, :files

        def initialize(depsYaml,fileName)
            
            self.fileName = fileName
            self.provides = depsYaml['provides-top-level'] || []
            self.nominals = depsYaml['provides-nominal']
            self.depends = depsYaml['depends-top-level'] || []
            self.files = Set.new
            self.realDeps = []
            # self.depends_member = depsYaml['depends-member'] || []

            if !self.provides.nil? &&
                !self.nominals.nil?
                self.realDeps = []

                self.depends.each do |d|
                    if valid_dep?(d)  &&
                        !self.provides.include?(d)
                        self.realDeps << d
                    end
                end
            end
        end

        def contains?(dep) 
            self.provides.contains? dep
        end

    def valid_dep?(dep)
      !dep.nil? && !/^(<\s)?\w/.match(dep).nil? && !keyword?(dep) && !framework?(dep)
    end
    private :valid_dep?

    def framework?(dep)
      /^(CA|CF|CG|CI|CL|kCA|NS|UI)/.match(dep) != nil
    end
    private :framework?

    def keyword?(dep)
      /^(Any|AnyBidirectionalCollection|AnyBidirectionalIndex|AnyClass|AnyForwardCollection|AnyForwardIndex|AnyObject|AnyRandomAccessCollection|AnyRandomAccessIndex|AnySequence|Array|ArraySlice|AutoreleasingUnsafeMutablePointer|BOOL|Bool|BooleanLiteralType|CBool|CChar|CChar16|CChar32|CDouble|CFloat|CInt|CLong|CLongLong|COpaquePointer|CShort|CSignedChar|CUnsignedChar|CUnsignedInt|CUnsignedLong|CUnsignedLongLong|CUnsignedShort|CVaListPointer|CWideChar|Character|ClosedInterval|ClusterType|CollectionOfOne|ContiguousArray|DISPATCH_|Dictionary|DictionaryGenerator|DictionaryIndex|DictionaryLiteral|Double|EmptyGenerator|EnumerateGenerator|EnumerateSequence|ExtendedGraphemeClusterType|FlattenBidirectionalCollection|FlattenBidirectionalCollectionIndex|FlattenCollectionIndex|FlattenSequence|Float|Float32|Float64|FloatLiteralType|GeneratorSequence|HalfOpenInterval|IndexingGenerator|Int|Int16|Int32|Int64|Int8|IntMax|IntegerLiteralType|JoinGenerator|JoinSequence|LazyCollection|LazyFilterCollection|LazyFilterGenerator|LazyFilterIndex|LazyFilterSequence|LazyMapCollection|LazyMapGenerator|LazyMapSequence|LazySequence|LiteralType|ManagedBufferPointer|Mirror|MutableSlice|ObjectIdentifier|Optional|PermutationGenerator|Range|RangeGenerator|RawByte|Repeat|ReverseCollection|ReverseIndex|ReverseRandomAccessCollection|ReverseRandomAccessIndex|ScalarType|Set|SetGenerator|SetIndex|Slice|StaticString|StrideThrough|StrideThroughGenerator|StrideTo|StrideToGenerator|String|String.CharacterView|String.CharacterView.Index|String.UTF16View|String.UTF16View.Index|String.UTF8View|String.UTF8View.Index|String.UnicodeScalarView|String.UnicodeScalarView.Generator|String.UnicodeScalarView.Index|StringLiteralType|UInt|UInt16|UInt32|UInt64|UInt8|UIntMax|UTF16|UTF32|UTF8|UnicodeScalar|UnicodeScalarType|Unmanaged|UnsafeBufferPointer|UnsafeBufferPointerGenerator|UnsafeMutableBufferPointer|UnsafeMutablePointer|UnsafePointer|Void|Zip2Generator|Zip2Sequence|abs|alignof|alignofValue|anyGenerator|anyGenerator|assert|assertionFailure|debugPrint|debugPrint|dispatch_|dump|dump|fatalError|getVaList|isUniquelyReferenced|isUniquelyReferencedNonObjC|isUniquelyReferencedNonObjC|max|max|min|min|numericCast|numericCast|numericCast|numericCast|precondition|preconditionFailure|print|print|readLine|sizeof|sizeofValue|strideof|strideofValue|swap|transcode|unsafeAddressOf|unsafeBitCast|unsafeDowncast|unsafeUnwrap|withExtendedLifetime|withExtendedLifetime|withUnsafeMutablePointer|withUnsafeMutablePointers|withUnsafeMutablePointers|withUnsafePointer|withUnsafePointers|withUnsafePointers|withVaList|withVaList|zip)$/.match(dep) != nil
    end

    end

    module SwiftDepsParser
        def self.parse(file)
            begin
                result = YAML.load_file(file)
            rescue 
            end
            result
        end
    end

    module SwifComplier
        
        def self.run(directory, deps)
            
            deps.each do |d|
                puts "Looking for: #{d.fileName} in #{directory}"
                path = Dir.glob("#{directory}/**/*.swift}")
                puts "#{path}" if !path.empty?
            end
        end
    end

    module XcodeBuilder
        def self.findDeriveDataPath(project,workspace,scheme)
             arg = if project
              "-project \"#{project}\""
            else
              "-workspace \"#{workspace}\""
            end

            arg+= " -scheme \"#{scheme}\"" if scheme

            build_settings = `xcodebuild #{arg} -showBuildSettings build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`
            raise StandardError until $?.success?

            derived_data_path = build_settings.match(/ OBJROOT = (.+)/)[1]
            project_name = build_settings.match(/ PROJECT_NAME = (.+)/)[1]
            target_name = build_settings.match(/ TARGET_NAME = (.+)/)[1]

            "#{derived_data_path}/#{project_name}.build/**/#{target_name}*.build"

        end

        def self.findFiles(project, workspace, scheme)
            derived_data_path = findDeriveDataPath(project, workspace, scheme)
            swiftdeps = Dir.glob("#{derived_data_path}/**/*.swiftdeps") if derived_data_path

            if swiftdeps.nil? || swiftdeps.empty?
                raise StandardError, 'No derived data found. Please make sure the project was built.'
            end

            swiftdeps
        end
    end

    def self.run(project, workspace, scheme)

        unless project || (workspace &&  scheme)
            raise StandardError, 'Must provide project path or workspace path with scheme.'
        end

        depsFiles = XcodeBuilder::findFiles(project,workspace,scheme)
        deps = []
        depsFiles.each do |file|
            parsed = SwiftDepsParser::parse(file)
            swiftFile = Pathname(file).basename.to_s.gsub 'swiftdeps','swift'
            deps << SwiftDepsModel.new(parsed, swiftFile) if !parsed.nil?
        end

        #TODO: there is a way to do this better i think
        deps.each do |d0|
            deps.each do |d1|
                d0.files << d1.fileName if !(d1.provides & d0.realDeps).empty? #NOTE: slow array logical operator think wbout how to do it faster
            end
        end

        SwifComplier::run(Pathname(project).dirname.to_s,deps)
        
    end

end
#TODO: for now it will be as a script cause of development purposes
SwiftDeadCode::run(ARGV[0],ARGV[1],ARGV[2])