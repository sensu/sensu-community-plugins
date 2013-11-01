require 'simplecov'
SimpleCov.start { add_filter '/spec' }

require File.expand_path('../../check_opentsdb_series', __FILE__)

FIXTURE_DIRECTORY = "#{File.dirname(__FILE__)}/resources/"
