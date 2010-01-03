require 'less' unless defined? Less
require 'active_support/core_ext/class/attribute_accessors'

# Yet another Less http://lesscss.org compiler.
class LessCompiler

  if defined? ActionView::Helpers::AssetTagHelper::STYLESHEETS_DIR
    @@source_path = ActionView::Helpers::AssetTagHelper::STYLESHEETS_DIR
  end
  cattr_accessor :source_path, :source_exclude

  def self.destination_path
    @@destination_path || source_path # make sure it defaults to source
  end
  cattr_writer :destination_path

  @@less_pattern = '**/[^_]*.less' # "partials" excluded by default
  cattr_accessor :less_pattern

  @@update_templates = :when_changed # :never, :when_changed or :allways
  cattr_accessor :update_templates, :compress

  @@check_imports = true
  cattr_accessor :check_imports

  if defined? RAILS_DEFAULT_LOGGER
    @@logger = RAILS_DEFAULT_LOGGER
  else
    require 'logger' unless defined? Logger
    @@logger = Logger.new($stdout)
  end
  cattr_accessor :logger

  def self.compile_stylesheets(options = {})
    self.new(options).compile_stylesheets
  end

  def initialize(attrs = {})
    self.class.class_variables.each do |cvar|
      var = cvar[2..-1].to_sym # '@@name' -> :name
      val = attrs.has_key?(var) ? attrs[var] : self.class.send(var)
      self.instance_variable_set(:"@#{var}", val)
    end
  end

  # Updates all stylesheets in the template_location and
  # create corresponding files in the destination_path.
  def compile_stylesheets
    raise "source_path is required" unless @source_path
    return if @update_templates == :never
    # Recursively loop through the directory specified in source_path :
    Dir.glob(File.join(@source_path, @less_pattern)).sort!.each do |stylesheet|
      case @source_exclude
        when Proc
          excluded = @source_exclude.call(stylesheet)
        when Regexp
          excluded = stylesheet =~ @source_exclude
        when true # makes no sense
          excluded = true
        else
          excluded = false
      end
      if excluded
        @logger.debug "LESS 'excluded' stylesheet: #{stylesheet}" if @logger
        next
      end
      # Update the current stylesheet if update is not :when_changed OR when
      # the less-file is newer than the css-file.
      if @update_templates != :when_changed || needs_update?(stylesheet)
        @logger.debug "LESS compiling stylesheet: #{stylesheet}" if @logger
        compile_stylesheet(stylesheet)
      end
    end
  end

  # Update a single stylesheet.
  def compile_stylesheet(stylesheet)
    relative_base = relative_base(stylesheet)
    # Remove the old generated stylesheet
    css_file = File.join(@destination_path, "#{relative_base}.css")
    #File.unlink(css_file) if File.exist?(css_file)
    # Generate the new stylesheet
    Less::Command.new(
      :source => stylesheet,
      :destination => css_file,
      :compress => !! @compress # e.g. Rails.env.production?
    ).parse( ! File.exist?(css_file) )
  end

  private

  # Check if the specified stylesheet is in need of an update.
  def needs_update?(less_file)
    css_file = File.join(@destination_path, "#{relative_base(less_file)}.css")
    return true unless File.exist?(css_file)
    File.mtime(less_file) > File.mtime(css_file) ||
    (@check_imports && contains_updated_import?(less_file, css_file))
  end

  # TODO @import file + mtime caching to speed up things ...

  def contains_updated_import?(less_file, css_file = nil)
    File.open(less_file) do |file|
      file.each_line do |line|
        if line =~ /@import\s*['"](.*)['"]\s*;/
          import_file = $~[1]
          #case File.extname(import_file)
          #  when '.css' then next
          #  when '' then import_file = "#{import_file}.less"
          #end
          if File.extname(import_file).empty?
            import_file = "#{import_file}.less"
          end
          if import_file[0, 1] != '/' # add file's relative path :
            import_file = File.join(File.dirname(file.path), import_file)
          end
          if css_file
            if File.mtime(import_file) > File.mtime(css_file)
              #puts "LESS contains updated import: #{$~[1]}"
              return true
            end
          else
            if File.mtime(import_file) > File.mtime(less_file)
              #puts "LESS contains updated import: #{$~[1]}"
              return true
            end
          end
          if needs_update?(import_file)
            #puts "LESS contains updated import: #{$~[1]}"
            return true
          end
        end
      end
    end
    false
  end

  # Returns the relative base for the given stylesheet
  def relative_base(stylesheet)
    path = stylesheet.sub(@source_path, '').sub('.less', '')
    path[0, 1] == '/' ? path[1..-1] : path
  end

end
