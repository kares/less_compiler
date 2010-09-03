LESS Compiler
==============

Yet another LESS helper for stylesheet compilation.

The main reason for creating this helper was to be able to compile
less stylesheets to css every time they change (during development)
with correct handling of css/less `@import 'file.less'` declarations.

Configuration
=============

Source path for .less files, defaults to `'public/stylesheets'` :

    LessCompiler.source_path = '/path/to/less/files'

Source files might be excluded (with a regexp or a proc) :

    LessCompiler.source_exclude = lambda do |file_name|
      # do not compile .less files under 'stylesheets/colors'
      File.dirname(file_name).ends_with?('stylesheets/colors')
    end

Destination path for .css files, defaults to source path :

    LessCompiler.destination_path = '/path/to/css/files'

Glob pattern for picking up less files, default `'**/[^_]*.less'` :

    LessCompiler.less_pattern = '**/*.less' # do not skip partials

When to update templates `:never`, `:when_changed` (default) or `:always` :

    LessCompiler.update_templates = :always # do not check mtimes

Whether to check @import files if recompilation is needed, this feature
implies updating templates set to :when_changed.

    LessCompiler.check_imports = false # it is on by default

e.g. suppose the content of `main.less` :

    @import '_init';
    .header a { text-decoration: none; }

every time `_init.less` partial is updated `main.less` should be recompiled !

All supported configuration options might be passed to `compile_stylesheets`
method directly :

    LessCompiler.compile_stylesheets(
        :source_path => MY_STYLES_DIR
        :update_templates => :always,
        :check_imports => false
    )

Installation
============

Please install LESS first :

    gem install less


Rails Setup
-----------

Install as a Ruby on Rails plugin :

    script/plugin install git://github.com/kares/less_compiler.git

The plugin does not depend on Rails nor does it perform anything during the
plugin init/install phase. You should configure it in an initializer :

    case Rails.env
    when 'development'
      # Compile less on every request
      ActionController::Base.before_filter do
        LessCompiler.compile_stylesheets
      end
    when 'production'
      # Compile less when the application loads or immediately ...
      if respond_to?(:config) && config.respond_to?(:after_initialize)
        config.after_initialize do
          LessCompiler.compile_stylesheets :compress => true
        end
      else
        LessCompiler.compile_stylesheets :compress => true
      end
    else
      # NOOP for 'test' env
    end

put this under e.g. `RAILS_ROOT/config/initializers/less_setup.rb`

LESS
----

LESS is the evolution of CSS with all the goodies You ever wanted.
For more information, see [http://lesscss.org](http://lesscss.org).

Originaly inspired by [http://github.com/karsthammer/less-rails](less-rails).
If this is not enought try [http://github.com/cloudhead/more](more).
