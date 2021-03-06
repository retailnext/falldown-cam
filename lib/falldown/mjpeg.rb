# Copyright (c) 2011, Nearbuy Systems, Inc.
# This material contains trade secrets and confidential information of
# Nearbuy Systems, Inc.  Any use, reproduction, disclosure or
# dissemination is strictly prohibited without the explicit written
# permission of Nearbuy Systems, Inc.
# All right reserved.
require 'net/http'

module Falldown
end

class Falldown::Mjpeg
  def initialize
    @urls = []
  end

  def <<(url)
    @urls << url
  end

  def go(&block)
    @threads = []
    @urls.each do |url|
      @threads << Thread.new { read_stream(url, &block) }
    end

    @threads.each {|t| t.join }
  end

  def stop
    @threads.each {|t| t.kill }
  end

  def read_stream(url, &block)
    loop do
      begin
        do_one_stream(url, &block)
      rescue Exception => e
        sleep(1)
      end
    end
  end

  def do_one_stream(url)
    Net::HTTP.get_response(URI(url)) do |res|
      state = :done
      frame = ''
      frame_remaining = 0
      read_buffer = ''

      frame_count = 0
      res.read_body do |chunk|
        read_buffer += chunk
        while !read_buffer.empty? do
          if state == :done
            if read_buffer =~ /Content-Length: (\d+)\r\n\r\n/
              state = :in_frame
              frame_remaining = $1.to_i
              read_buffer.slice!(0, read_buffer.index("\r\n\r\n")+4)
            end
          end

          if state == :in_frame
            got = read_buffer.slice!(0, frame_remaining > read_buffer.size ? read_buffer.size : frame_remaining)
            frame_remaining -= got.size
            frame += got
          else
            break
          end

          if frame_remaining == 0 && state == :in_frame
            yield(url, frame)

            state = :done
            frame = ''
          end
        end
      end
    end
  end
end
