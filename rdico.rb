#!/usr/bin/env ruby

SHARD_ID = ARGV[0]
MAX_SHARD = ARGV[1]
if SHARD_ID.nil? || MAX_SHARD.nil? || SHARD_ID.empty? || MAX_SHARD.empty?
  return puts "## No shard_id and max_shard"
end

APP_ROOT = ENV['RAILS_ENV'] == "production" ? "/opt/www/l2mh" : "/home/duecorda/Projects/l2mh"
WHICH_RAKE = ENV['RAILS_ENV'] == "production" ? "/home/ubuntu/.rbenv/shims/rake" : "/home/duecorda/.rbenv/shims/rake"
RAKE_FILE = ENV['RAILS_ENV'] == "production" ? "live_dicobot" : "dev_dicobot"

def restart(pid=nil)
  `cp #{APP_ROOT}/services/drb.log #{APP_ROOT}/services/drb.bak`
  `cp #{APP_ROOT}/services/dico.log #{APP_ROOT}/services/dico.bak`
  if !pid.nil?
    pid.each {|x| `kill -1 #{x}`}
    sleep(1)
  end
  `cd #{APP_ROOT};#{WHICH_RAKE} #{RAKE_FILE}[#{SHARD_ID},#{MAX_SHARD}] >#{APP_ROOT}/services/drb.log 2>&1 &`
  puts "## Restarted"
end

pids = `ps x | grep 'rake.*_dicobot' | grep -v grep | awk '{ print $1 }'`
pid = pids.split(/[\r\n]/)
if pid.length >= 2
  puts "## Multiple Process"
  pid.each {|x| `kill -9 #{x}`}
  return restart 
elsif pid.length == 0
  puts "## No Process"
  return restart 
end

drb_log_path = "#{APP_ROOT}/services/drb.log"
dat = `tail -n 50 #{drb_log_path}`
lines = dat.split(/[\r\n]/)

lines.reverse.each do |line|
  if /^\[INFO.*Discord.using.gateway.protocol.version:.[0-9],.requested:.[0-9]$/.match(line)
    return puts "## Normal"
  elsif /^\[ERROR/.match(line)
    puts line
    return restart(pid)
  end
end
