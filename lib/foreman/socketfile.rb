require "socket"

class Foreman::Socketfile

  # Parse a Socketfile.
  #
  # Format:
  #   process-name: name=tcp://host:port [name=tcp://host:port ...]
  #   process-name: name=unix:///path/to/socket
  #
  # Example:
  #   hydra-server: http=tcp://:3000
  #   hydra-queue-runner: rest=tcp://:8080 grpc=tcp://:50051
  #   hydra-drv-daemon: daemon=unix:///tmp/drv-daemon.sock
  #
  def initialize(filename)
    @entries = {}
    return unless filename && File.exist?(filename)

    File.read(filename).lines.each do |line|
      line = line.strip
      next if line.empty? || line.start_with?("#")

      process_name, sockets_str = line.split(":", 2)
      next unless sockets_str

      process_name = process_name.strip
      @entries[process_name] = parse_sockets(sockets_str.strip)
    end
  end

  # Get socket declarations for a process.
  #
  # @param [String] name  The process name
  # @return [Array<Hash>]  Array of { name:, type:, ... } hashes, or empty array.
  #   TCP:  { name:, type: :tcp, host:, port: }
  #   Unix: { name:, type: :unix, path: }
  #
  def sockets_for(name)
    @entries[name] || []
  end

  # Whether any sockets are declared.
  #
  def any?
    !@entries.empty?
  end

  private

  def parse_sockets(str)
    str.split(/\s+/).map do |spec|
      name, addr = spec.split("=", 2)
      unless addr
        addr = name
        name = nil
      end

      scheme, rest = addr.split("://", 2)
      raise "missing scheme in #{spec.inspect}; use tcp:// or unix://" unless rest

      case scheme
      when "tcp"
        host, port = parse_tcp_addr(rest)
        { name: name, type: :tcp, host: host, port: port.to_i }
      when "unix"
        { name: name, type: :unix, path: rest }
      else
        raise "unknown socket scheme #{scheme.inspect} in #{spec.inspect}; use tcp:// or unix://"
      end
    end
  end

  def parse_tcp_addr(addr)
    if addr.start_with?("[")
      # IPv6: [::1]:port or [::]:port
      bracket_end = addr.index("]")
      host = addr[1...bracket_end]
      port = addr[(bracket_end + 2)..]
      [host, port]
    elsif addr.start_with?(":")
      # :port (all interfaces)
      ["::", addr[1..]]
    elsif addr.include?(":")
      # host:port
      parts = addr.rpartition(":")
      [parts[0], parts[2]]
    else
      # just a port
      ["::", addr]
    end
  end

end
