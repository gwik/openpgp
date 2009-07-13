module OpenPGP
  ##
  # OpenPGP ASCII Armor utilities.
  #
  # @see http://tools.ietf.org/html/rfc4880#section-6.2
  module Armor
    ##
    # @see http://tools.ietf.org/html/rfc4880#section-6.2
    module Markers
      MESSAGE           = 'MESSAGE'
      PUBLIC_KEY_BLOCK  = 'PUBLIC KEY BLOCK'
      PRIVATE_KEY_BLOCK = 'PRIVATE KEY BLOCK'
      SIGNATURE         = 'SIGNATURE'
      ARMORED_FILE      = 'ARMORED FILE' # a GnuPG extension
    end

    def self.marker(marker)
      marker = Markers.const_get(marker.to_s.upcase.to_sym) if marker.is_a?(Symbol)
      marker.to_s.upcase
    end

    ##
    # @see http://tools.ietf.org/html/rfc4880#section-6.2
    def self.header(marker)
      "-----BEGIN PGP #{marker(marker)}-----"
    end

    ##
    # @see http://tools.ietf.org/html/rfc4880#section-6.2
    def self.footer(marker)
      "-----END PGP #{marker(marker)}-----"
    end

    ##
    # @see http://tools.ietf.org/html/rfc4880#section-6
    # @see http://tools.ietf.org/html/rfc4880#section-6.2
    # @see http://tools.ietf.org/html/rfc2045
    def self.encode(data, marker = :message, headers = {})
      Buffer.write do |text|
        text << self.header(marker)     << "\n"
        headers.each { |key, value| text << "#{key}: #{value}\n" }
        text << "\n" << encode64(data)
        text << "="  << encode64([OpenPGP.crc24(data)].pack('N')[1, 3])
        text << self.footer(marker)     << "\n"
      end
    end

    ##
    # @see http://tools.ietf.org/html/rfc4880#section-6
    # @see http://tools.ietf.org/html/rfc2045
    def self.decode(text, marker = nil)
      data, crc, state = Buffer.new, nil, :begin
      text.each_line do |line|
        line.chomp!
        case state
          when :begin
            case line
              when /^-----BEGIN PGP ([^-]+)-----$/
                state = :head if marker.nil? || marker.to_s.upcase == $1
            end
          when :head
            state = :body if line =~ /^\s*$/
          when :body
            case line
              when /^=(....)$/
                crc = ("\0" << decode64($1)).unpack('N').first
                state = :end
              when /^-----END PGP ([^-]+)-----$/
                state = :end
              else
                data << decode64(line)
            end
          when :end
            break
        end
      end
      data.string
    end

    protected

      ##
      # Returns the Base64-encoded version of +input+, with a configurable
      # output line length.
      def self.encode64(input, line_length = nil)
        if line_length.nil?
          [input].pack('m')
        elsif line_length % 4 == 0
          [input].pack("m#{(line_length / 4) * 3}")
        else
          output = []
          [input].pack('m').delete("\n").scan(/.{1,#{line_length}}/) do
            output << $&
          end
          output << ''
          output.join("\n")
        end
      end

      ##
      # Returns the Base64-decoded version of +input+.
      def self.decode64(input)
        input.unpack('m').first
      end
  end

  include Armor::Markers
end
