#!/usr/bin/env ruby

#
# Check for malfunctioning RAID array.
#
# Supports HP, Adaptec, and MegaRAID controllers. Also supports software RAID.
#
# Originally by Shane Feek, modified by Alan Smith.
# Date: 07/14/2014
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class CheckRaid < Sensu::Plugin::Check::CLI
  def check_software
    # #YELLOW
    if File.exist?('/proc/mdstat') # rubocop:disable GuardClause
      contents = File.read('/proc/mdstat')
      mg = contents.lines.grep(/active/)
      unless mg.empty?
        sg = mg.to_s.lines.grep(/\]\(F\)/)
        # #YELLOW
        unless sg.empty? # rubocop:disable UnlessElse
          warning 'Software RAID warning'
        else
          ok 'Software RAID OK'
        end
      end
    end
  end

  def check_hp
    # #YELLOW
    if File.exist?('/usr/bin/cciss_vol_status')  # rubocop:disable GuardClause
      contents = `/usr/bin/cciss_vol_status /dev/sg0`
      c = contents.lines.grep(/status\: OK\./)
      # #YELLOW
      unless c.empty?  # rubocop:disable UnlessElse
        ok 'HP RAID OK'
      else
        warning 'HP RAID warning'
      end
    end
  end

  def check_adaptec
    # #YELLOW
    if File.exist?('/usr/StorMan/arcconf')  # rubocop:disable GuardClause
      contents = `/usr/StorMan/arcconf GETCONFIG 1 AL`

      mg = contents.lines.grep(/Controller Status/)
      # #YELLOW
      unless mg.empty?  # rubocop:disable UnlessElse
        sg = mg.to_s.lines.grep(/Optimal/)
        warning 'Adaptec Physical RAID Controller Failure' if sg.empty?
      else
        warning 'Adaptec Physical RAID Controller Status Read Failure'
      end

      mg = contents.lines.grep(/Status of logical device/)
      # #YELLOW
      unless mg.empty?   # rubocop:disable UnlessElse
        sg = mg.to_s.lines.grep(/Optimal/)
        warning 'Adaptec Logical RAID Controller Failure' if sg.empty?
      else
        warning 'Adaptec Logical RAID Controller Status Read Failure'
      end

      mg = contents.lines.grep(/S\.M\.A\.R\.T\.   /)
      # #YELLOW
      unless mg.empty?   # rubocop:disable UnlessElse
        sg = mg.to_s.lines.grep(/No/)
        warning 'Adaptec S.M.A.R.T. Disk Failed' if sg.empty?
      else
        warning 'Adaptec S.M.A.R.T. Status Read Failure'
      end

      ok 'Adaptec RAID OK'
    end
  end

  def check_mega_raid
    # #YELLOW
    if File.exist?('/usr/sbin/megacli')  # rubocop:disable GuardClause
      contents = `/usr/sbin/megacli -AdpAllInfo -aALL`
      c = contents.lines.grep(/(Critical|Failed) Disks\s+\: 0/)
      # #YELLOW
      unless c.empty?   # rubocop:disable UnlessElse
        ok 'MegaRaid RAID OK'
      else
        warning 'MegaRaid RAID warning'
      end
    end
  end

  def run
    unless `lspci`.lines.grep(/RAID/).empty?
      check_software
      check_hp
      check_adaptec
      check_mega_raid

      unknown 'Missing software for RAID controller'
    end

    ok 'No RAID present'
  end
end
