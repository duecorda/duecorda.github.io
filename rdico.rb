#!/usr/bin/env ruby

should_restart = false

drb_log_path = "/opt/www/l2mh/services/drb.log"
dat = `tail -n 50 #{drb_log_path}`
lines = dat.split(/[\r\n]/)
lines.reverse.each do |line|
  if /^\[ERROR/.match(line)
    should_restart = true
    break
  end
end

if should_restart
  clue = `ps aux | grep 'rake.*_dicobot' | grep -v grep`
  if clue.blank?
    puts "####"
    puts "## Not Found Process"
    puts "####"
  else
    items = clue.split(/\s+/)
    pid = items[1]
    prs = items[-1]

    shard_id = /\[([0-9]+),/.match(prs).to_a.last
    max = /\[[0-9]+,([0-9]+)\]/.match(prs).to_a.last

    `kill -SIGHUP #{pid}`
    sleep(1)
    `/home/ubuntu/.rbenv/shims/rake live_dicobot[#{shard_id},#{max}] >/opt/www/l2mh/services/drb.log 2>&1 &`
  end
end
