# Copyright (c) 2011, Nearbuy Systems, Inc.
# This material contains trade secrets and confidential information of
# Nearbuy Systems, Inc.  Any use, reproduction, disclosure or
# dissemination is strictly prohibited without the explicit written
# permission of Nearbuy Systems, Inc.
# All right reserved.
require 'net/http'

class Mjpeg
  def initialize(url)
    @url = url
  end

  def go
    Net::HTTP.get_response(URI(@url)) do |res|
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
              read_buffer.sub!(/.*?\r\n\r\n/m, '')
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
            yield(frame)

            state = :done
            frame = ''
          end
        end
      end
    end
  end
end
