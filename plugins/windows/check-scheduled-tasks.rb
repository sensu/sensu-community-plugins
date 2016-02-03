#!/usr/bin/env ruby
#
# Check Scheduled Task Plugin
# ===
#
# throws a warning for any disabled scheduled task
require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class CheckSheduledTask < Sensu::Plugin::Check::CLI
  option :name,
         short: '-n Name',
         description: 'Specify a specific task to monitor.'

  option :ignore,
         short: '-i Ignore',
         description: 'Ignore certain scheduled tasks',
         proc: proc { |a| a.split(',').select(&:chomp) }

  option :directory,
         short: '-d Directory',
         description: 'Only select tasks within the specified tasks directory(ies)',
         proc: proc { |a| a.split(',').select(&:chomp) }

  def initialize
    super
    @tasks = []
  end

  def read_schtask
    name = "/TN #{config[:name]}" unless config[:name].nil?
    @tasks = `schtasks /Query /FO CSV #{name}`
             .lines
             .select { |task| task != "\"TaskName\",\"Next Run Time\",\"Status\"\n" }
             .map do |task|
      split = task.tr('\"', '').split(',')
      { name: split[0], next_run: split[1], status: split[2].chomp }
    end

    unless config[:directory].nil?
      @tasks.select! { |task| config[:directory].any? { |folder_name| task[:name].start_with?(folder_name) } }
    end

    unless config[:ignore].nil?
      @tasks.select! { |task| !config[:ignore].any? { |ignore| task[:name] == ignore } }
    end
  end

  def summary(tasks)
    tasks.map { |task| "Name: #{task[:name]}, Next Run: #{task[:next_run]}, Status: #{task[:status]}" }.join('\n')
  end

  def disabled?
    disabled_tasks.any?
  end

  def disabled_tasks
    @tasks.select { |task| task[:next_run].casecmp('disabled') }
  end

  def run
    read_schtask
    conf = ''

    unless config[:directory].nil?
      conf << "\nDirectories: #{config[:directory].join(', ')}"
    end

    unless config[:ignore].nil?
      conf << "\nIgnoring: #{config[:ignore].join(', ')}"
    end

    warning(summary(disabled_tasks) + conf) if disabled?
    output_string = summary(@tasks)
    ok(output_string + conf)
  end
end
