#!/usr/bin/ruby

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
  def CheckSoftware
    if File.exist?('/proc/mdstat')
      contents = File.read('/proc/mdstat')
      mg = contents.lines.grep(/active/)
      unless mg.empty?
        sg = mg.to_s.lines.grep(/\]\(F\)/)
        unless sg.empty?
          warning 'Software RAID warning'
        else
          ok 'Software RAID OK'
        end
      end
    end
  end

  def CheckHP
    if File.exist?('/usr/bin/cciss_vol_status')
      contents = `/usr/bin/cciss_vol_status /dev/sg0`
      c = contents.lines.grep(/status\: OK\./)
      unless c.empty?
        ok 'HP RAID OK'
      else
        warning 'HP RAID warning'
      end
    end
  end

  def CheckAdaptec
    if File.exist?('/usr/StorMan/arcconf')
      contents = `/usr/StorMan/arcconf GETCONFIG 1 AL`

      mg = contents.lines.grep(/Controller Status/)
      unless mg.empty?
        sg = mg.to_s.lines.grep(/Optimal/)
        if sg.empty?
          warning 'Adaptec Physical RAID Controller Failure'
        end
      else
        warning 'Adaptec Physical RAID Controller Status Read Failure'
      end

      mg = contents.lines.grep(/Status of logical device/)
      unless mg.empty?
        sg = mg.to_s.lines.grep(/Optimal/)
        if sg.empty?
          warning 'Adaptec Logical RAID Controller Failure'
        end
      else
        warning 'Adaptec Logical RAID Controller Status Read Failure'
      end

      mg = contents.lines.grep(/S\.M\.A\.R\.T\.   /)
      unless mg.empty?
        sg = mg.to_s.lines.grep(/No/)
        if sg.empty?
          warning 'Adaptec S.M.A.R.T. Disk Failed'
        end
      else
        warning 'Adaptec S.M.A.R.T. Status Read Failure'
      end

      ok 'Adaptec RAID OK'
    end
  end

  def CheckMegaRaid
    if File.exist?('/usr/sbin/megacli')
      contents = `/usr/sbin/megacli -AdpAllInfo -aALL`
      c = contents.lines.grep(/(Critical|Failed) Disks\s+\: 0/)
      unless c.empty?
        ok 'MegaRaid RAID OK'
      else
        warning 'MegaRaid RAID warning'
      end
    end
  end

  def run
    unless `lspci`.lines.grep(/RAID/).empty?
      CheckSoftware()
      CheckHP()
      CheckAdaptec()
      CheckMegaRaid()

      unknown 'Missing software for RAID controller'
    end

    ok 'No RAID present'
  end
end
