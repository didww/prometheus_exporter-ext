# frozen_string_literal: true

module PrometheusExporter::Ext
  # https://man7.org/linux/man-pages/man5/proc_pid_stat.5.html
  class ProcSelfStat
    KERNEL_PAGE_SIZE = `getconf PAGESIZE`.chomp.to_i rescue 4096 # rubocop:disable Style/RescueModifier

    class << self
      def get
        stat = File.read('/proc/self/stat')
        parts = stat.match(/\A(\d+)\s\((.*)\)\s([A-Z])\s(.*)/)[1..]
        rest = parts.pop.split
        new(*parts, *rest)
      end
    end

    attr_reader :pid,
                :comm,
                :state,
                :utime,
                :stime,
                :starttime,
                :vsize,
                :rss

    def initialize(*fields)
      @pid = fields[0]
      @comm = fields[1]
      @state = fields[2]
      @utime = Integer(fields[13])
      @stime = Integer(fields[14])
      @starttime = Integer(fields[21])
      @vsize = Integer(fields[22])
      @rss = Integer(fields[23])
      @fields = fields
    end

    # @return [Float]
    def cpu_time
      ticks_per_sec = Etc.sysconf(Etc::SC_CLK_TCK)
      (utime + stime).to_f / ticks_per_sec
    end

    # @return [Integer]
    def rss_bytes
      rss * KERNEL_PAGE_SIZE
    end

    # @return [Float]
    def uptime_seconds
      uptime_seconds = File.read('/proc/uptime').split[0].to_f
      ticks_per_sec = Etc.sysconf(Etc::SC_CLK_TCK)
      uptime_seconds - (starttime.to_f / ticks_per_sec)
    end

    def to_a
      @fields.dup
    end

    def to_h
      {
        pid:,
        comm:,
        state:,
        utime:,
        stime:,
        starttime:,
        vsize:,
        rss:
      }
    end

    def to_s
      "#<#{self.class.name} #{to_h.map { |k, v| "#{k}=#{v.inspect}" }.join(' ')}>"
    end

    def inspect
      to_s
    end
  end
end
