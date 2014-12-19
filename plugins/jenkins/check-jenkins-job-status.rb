#! /usr/bin/env ruby
#
#   check-jenkins-job-status
#
# DESCRIPTION:
#   Query jenkins API asking for job status
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   jenkins_api_client
#
# USAGE:
#   #YELLOW
#
# NOTES:
#   #YELLOW
#   add authorization options
#   add url to job's log for CRITICAL state
#
# LICENSE:
#   Copyright 2014 SUSE, GmbH <happy-customer@suse.de>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'jenkins_api_client'

class JenkinsJobChecker < Sensu::Plugin::Check::CLI
  option :server_api_url,
         description: 'hostname running Jenkins API',
         short: '-u JENKINS-API-HOST',
         long: '--url JENKINS-API-HOST',
         required: true

  option :job_list,
         description: 'Name of a job/pattern to query. Wrap with quotes. E.g. \'^GCC\'',
         short: '-j JOB-LIST',
         long: '--jobs JOB-LIST',
         required: true

  option :client_log_level,
         description: 'log level option 0..3 to client',
         short: '-v CLIENT-LOG-LEVEL',
         long: '--verbose CLIENT-LOG-LEVEL',
         default: 3

  def run
    if failed_jobs.any?
      critical "Jobs reporting failure: #{failed_jobs_names}"
    else
      ok 'All queried jobs reports success'
    end
  end

  private

  def jenkins_api_client
    @jenkins_api_client ||= JenkinsApi::Client.new(
        server_ip: config[:server_api_url],
        log_level: config[:client_log_level].to_i
    )
  end

  def jobs_statuses
    if config[:job_list] =~ /\^/
      # #YELLOW
      jenkins_api_client.job.list(config[:job_list]).reduce({}) do |listing, job_name| # rubocop:disable Style/EachWithObject
        listing[job_name] = job_status(job_name)
        listing
      end
    else
      { config[:job_list] => job_status(config[:job_list]) }
    end
  end

  def job_status(job_name)
    jenkins_api_client.job.get_current_build_status(job_name)
  end

  def failed_jobs
    jobs_statuses.select { |_job_name, status| status == 'failure' }
  end

  def failed_jobs_names
    failed_jobs.keys.join(', ')
  end
end
