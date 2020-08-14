#!/usr/bin/env ruby

drb_log_path = "/opt/www/l2mh/services/drb.log"
dat = `tail -n 50 #{drb_log_path}`
lines = dat.split(/[\r\n]/)

should_restart = false
lines.reverse.each do |line|
  if /^\[INFO.*Discord.using.gateway.protocol.version:.[0-9],.requested:.[0-9]$/.match(line)
    return puts "## Normal"
  elsif /^\[ERROR/.match(line)
    should_restart = true
    break
  end
end

if should_restart
  puts "## Shold restart"
  clue = `ps aux | grep 'rake.*_dicobot' | grep -v grep`
  if clue.nil? || clue.empty?
    return puts "## Not Found Process"
  end

  items = clue.split(/\s+/)
  pid = items[1]
  prs = items[-1]

  if pid.nil? || pid.empty? || prs.nil? || prs.empty?
    return puts "## Not Found. pid: #{pid}, prs: #{prs}"
  end

  shard_id = /\[([0-9]+),/.match(prs).to_a.last
  max = /\[[0-9]+,([0-9]+)\]/.match(prs).to_a.last

  if shard_id.nil? || max.nil?
    return puts "## Not Found. shard_id: #{shard_id}, max: #{max}"
  end

  `kill -SIGHUP #{pid}`
  sleep(1)
  `cd /opt/www/l2mh;/home/ubuntu/.rbenv/shims/rake live_dicobot[#{shard_id},#{max}] >/opt/www/l2mh/services/drb.log 2>&1 &`
  puts "## Done"
end
