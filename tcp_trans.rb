require "socket"
require "open-uri"
require "logger"

class Server

  HealthInteval = 60

  def initialize(ip, port)
    @logger = Logger.new("log.txt")
    @server = TCPServer.open(ip, port)

    @connections = { server: @server, clients: {}, pong: {} }
    @pool = Hash.new

    @logger.info 'Started...'
    pingpong
    run
  end

  def pingpong
    Thread.new do
      while true
        @connections[:pong].each do |cip, pong_at|
          idle_time = Time.now.to_i - pong_at.to_i
          if idle_time > Server::HealthInteval * 2 # dead
            close_connection(cip)
          elsif idle_time > Server::HealthInteval
            ping(cip)
          end
        end
        sleep(Server::HealthInteval / 2)
      end
    end
  end

  def run
    loop {
      connection = @server.accept
      begin
        Thread.start(connection) do |client|
          cip = client.peeraddr[2].to_s.to_sym

          @connections[:clients].each do |other_cip, other_client|
            if cip == other_cip || client == other_client
              other_client.close
            end
          end
          @connections[:clients][cip] = client
          @connections[:pong][cip] = Time.now.to_i

          @logger.info "#{cip} connected"
          listen_client(cip, client)
        end
      rescue Exception => e
        @logger.error e.inspect
        connection.close
      end
    }.join
  end

  def listen_client(cip, client)
    loop do
      begin
        msg = client.gets(sep=[0x03].pack("C")).chomp rescue nil
        res = parsePayload(msg)

        if res.nil? || res.empty?
          close_connection(cip)
          break
        end

        if bell?(res)
          close_connection(cip)
          @logger.info "bell #{res[:body]}"
          poolling(res[:body])
        end

        if pong?(res)
          updatePongAt(cip)
          @logger.info "got pong from #{cip}"
          @logger.info res
        end

        if received?(res)
          @logger.info "got received signal #{res[:body]} from #{cip}"
          @pool.delete(res[:body])
          @logger.info @pool.inspect
          @logger.info res
        end

      rescue Exception => e
        @logger.error e.inspect
        close_connection(cip)
        break
      end
    end
  end

  def bell?(res)
    res[:stx].eql?([0x02].pack("C")) && 
    res[:dat].eql?([0x07].pack("C")) &&
    res[:etx].eql?([0x03].pack("C"))
  end

  def ping(cip)
    payload = "#{[0x02].pack('C')}#{[0x06].pack('C')}0000004PING#{[0x03].pack('C')}"
    @connections[:clients][cip].write payload
    @logger.info "send ping to #{cip}"
    @logger.info payload
  end

  def pong?(res)
    res[:stx].eql?([0x02].pack("C")) && 
    res[:dat].eql?([0x06].pack("C")) &&
    res[:body].eql?("PONG") &&
    res[:etx].eql?([0x03].pack("C"))
  end

  def received?(res)
    res[:stx].eql?([0x02].pack("C")) && 
    res[:dat].eql?([0x05].pack("C")) &&
    res[:etx].eql?([0x03].pack("C"))
  end

  def updatePongAt(cip)
    @connections[:pong][cip] = Time.now.to_i
  end

  def poolling(uri)
    k = /(A[0-9]+)_..xml$/i.match(uri).to_a.last
    @logger.info "pool key: #{k}"
    @pool[k] = uri
    @logger.info @pool.inspect

    send_article(k)
  end

  def send_article(k)
    return if @pool.empty?

    uri = @pool[k]
    article = open(uri) {|f| f.read}
    article.force_encoding("UTF-8")
    article = article.gsub(/[\r\n]/, '')
    article = article.encode('EUC-KR', invalid: :replace, undef: :replace, replace: ' ')

    @connections[:clients].each do |cip, client|
      payload = "#{[0x02].pack('C')}#{[0x04].pack('C')}#{zerofill(article.bytesize, 7)}#{article}#{[0x03].pack('C')}"
      client.write payload
      @logger.info "#{cip} send_article #{uri}"
      @logger.info payload
    end
  end

  def zerofill(n, l = 7)
    n = 0 if n.to_s.strip.empty?
    n.to_s.length < l ? (("0" * (l - n.to_s.length)) + n.to_s) : n
  end

  def parsePayload(payload)
    return if payload.nil? || payload.empty?

    begin
      res = Hash.new
      res[:stx] = payload[0,1]
      res[:dat] = payload[1,1]
      res[:length] = payload[2,7]
      res[:body] = payload[9,res[:length].to_i]
      res[:etx] = payload[-1]
  
      @logger.info res
      return res
    rescue
      return nil
    end
  end

  def close_all_connection
    @connections[:clients].each do |cip, client|
      close_connection(cip)
    end
  end

  def close_connection(cip)
    begin
      @connections[:clients][cip].close
      @connections[:clients].delete(cip)
      @connections[:pong].delete(cip)
    rescue
      # notthing to do
    end
  end

end

Server.new("172.31.28.195", 12313)
