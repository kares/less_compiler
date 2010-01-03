require 'test_helper'

require 'set'
require 'fileutils'

class LessCompilerTest < ActiveSupport::TestCase

  setup :reset_class_variables, :clean_stylesheets_dir

  test "destination_path defaults to source_path unless set" do
    assert_equal LessCompiler.source_path, LessCompiler.destination_path
    LessCompiler.destination_path = Dir.getwd
    assert_not_equal LessCompiler.source_path, LessCompiler.destination_path
  end

  test "1 - compiles less files with missing css files" do
    LessCompiler.source_path = File.join(STYLESHEETS_DIR, '1')
    LessCompiler.compile_stylesheets

    assert File.exist?( "#{LessCompiler.destination_path}/another.css" )
    assert File.exist?( "#{LessCompiler.destination_path}/some.css" )
  end

  test "1 - source_exclude is applied if set to a proc" do
    LessCompiler.source_path = File.join(STYLESHEETS_DIR, '1')
    LessCompiler.source_exclude = lambda do |file|
      File.basename(file) == 'some.less'
    end
    LessCompiler.compile_stylesheets

    assert File.exist?( "#{LessCompiler.destination_path}/another.css" )
    assert ! File.exist?( "#{LessCompiler.destination_path}/some.css" )
  end

  test "1 - source_exclude is applied if set to a regex" do
    LessCompiler.source_path = File.join(STYLESHEETS_DIR, '1')
    LessCompiler.compile_stylesheets :source_exclude => /another/

    assert ! File.exist?( "#{LessCompiler.destination_path}/another.css" )
    assert File.exist?( "#{LessCompiler.destination_path}/some.css" )
  end

  test "2 - compiles less files that are newer than css files" do
    LessCompiler.source_path = dir = File.join(STYLESHEETS_DIR, '2')
    FileUtils.touch [ "#{dir}/another.less" ]
    FileUtils.touch [ "#{dir}/some.css", "#{dir}/another.css" ]
    sleep 1 # mtime seconds precision
    FileUtils.touch [ "#{dir}/some.less" ]
    some_css_mtime = File.mtime "#{dir}/some.css"
    another_css_mtime = File.mtime "#{dir}/another.css"
    LessCompiler.compile_stylesheets

    assert_file_has_newer_mtime "#{LessCompiler.destination_path}/some.css", some_css_mtime
    assert_file_has_same_mtime "#{LessCompiler.destination_path}/another.css", another_css_mtime
  end

  test "3 - partial less stylesheets are not compiled if pattern does not match" do
    LessCompiler.source_path = dir = File.join(STYLESHEETS_DIR, '3')
    LessCompiler.less_pattern = '**/[^_]*.less' # default
    FileUtils.touch [ "#{dir}/main.css" ]
    sleep 1 # mtime seconds precision
    FileUtils.touch [ "#{dir}/_init.less", "#{dir}/main.less" ]
    main_css_mtime = File.mtime "#{dir}/main.css"
    LessCompiler.compile_stylesheets

    assert_file_has_newer_mtime "#{LessCompiler.destination_path}/main.css", main_css_mtime
    assert ! File.exist?( "#{LessCompiler.destination_path}/_init.css" )
  end

  test "4 - partial less stylesheet update forces main compilation if check_imports is on" do
    LessCompiler.source_path = dir = File.join(STYLESHEETS_DIR, '4')
    FileUtils.touch [ "#{dir}/main.less" ]
    FileUtils.touch [ "#{dir}/main.css" ]
    sleep 1 # mtime seconds precision
    FileUtils.touch [ "#{dir}/_init1.css" ] # doesn't matter which one will touch
    main_css_mtime = File.mtime "#{dir}/main.css"
    LessCompiler.compile_stylesheets :check_imports => true

    assert_file_has_newer_mtime "#{LessCompiler.destination_path}/main.css", main_css_mtime
  end

  test "4 - partial less stylesheet update does not forces main compilation if check_imports is off" do
    LessCompiler.source_path = dir = File.join(STYLESHEETS_DIR, '4')
    LessCompiler.check_imports = false
    FileUtils.touch [ "#{dir}/main.less" ]
    FileUtils.touch [ "#{dir}/main.css" ]
    sleep 1 # mtime seconds precision
    FileUtils.touch [ "#{dir}/_init1.css", "#{dir}/_init2.css", "#{dir}/_init3.css" ]
    main_css_mtime = File.mtime "#{dir}/main.css"
    LessCompiler.compile_stylesheets

    assert_file_has_same_mtime "#{LessCompiler.destination_path}/main.css", main_css_mtime
  end

  protected

  def assert_file_has_same_mtime(file, mtime)
    file_mtime = File.mtime(file)
    assert file_mtime == mtime, "#{file_mtime} is not the same as #{mtime}"
  end

  def assert_file_has_newer_mtime(file, mtime)
    file_mtime = File.mtime(file)
    assert file_mtime > mtime, "#{file_mtime} is not newer than #{mtime}"
  end

  private

  STYLESHEETS_DIR = File.join(File.dirname(__FILE__), 'stylesheets')
  if ! File.exist?(STYLESHEETS_DIR) || ! File.directory?(STYLESHEETS_DIR)
    raise "missing #{STYLESHEETS_DIR}"
  end
  
  STYLESHEETS_DIR_ENTRIES = Set.new Dir.glob("#{STYLESHEETS_DIR}/**/*")

  def clean_stylesheets_dir
    entries = Set.new Dir.glob("#{STYLESHEETS_DIR}/**/*")
    FileUtils.remove( (entries - STYLESHEETS_DIR_ENTRIES).to_a )
  end

  LESS_COMPILER_VAR_DEFAULTS = {}
  LessCompiler.class_variables.map{ |var| var.to_sym }.each do |var|
    val = LessCompiler.send :class_variable_get, var
    LESS_COMPILER_VAR_DEFAULTS[var] = val
  end

  def reset_class_variables
    LESS_COMPILER_VAR_DEFAULTS.each do |var, val|
      LessCompiler.send :class_variable_set, var, val
    end
  end

end
