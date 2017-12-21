require 'fluent/plugin/parser'
require 'fluent/time'
module Fluent
  module Plugin
    class KVParser < Parser
      Plugin.register_parser('kv', self)
      include Fluent::Configurable

      config_param :kv_delimiter, :string, :default => '\t\s'
      config_param :kv_char, :string, :default => '='
      config_param :time_key, :string, :default => 'time'
      config_param :time_format, :string, :default => nil

      def configure(conf={})
        super
        if @kv_delimiter[0] == '/' and @kv_delimiter[-1] == '/'
          @kv_delimiter = Regexp.new(@kv_delimiter[1..-2])
        end
        @time_parser = time_parser_create(format: @time_format)
        @kv_regex_str = '("(?:(?:\\\.|[^"])*)"|(?:[^' + @kv_delimiter + ']*))\s*' + @kv_char + '\s*("(?:(?:\\\.|[^"])*)"|(?:[^' + @kv_delimiter + ']*))'
        @kv_regex = Regexp.new(@kv_regex_str)
      end

      def parse(text)
        record = {}

        text.scan(@kv_regex) do | m |
          k = (m[0][0] == '"' and m[0][-1] == '"') ? m[0][1..-2] : m[0]
          v = (m[1][0] == '"' and m[1][-1] == '"') ? m[1][1..-2] : m[1]
          if record.has_key?(k)
            if record[k].is_a?(Array)
              record[k].push(v)
            else
              previous = record.delete(k)
              record[k] = [previous, v]
            end
          else
            record[k] = v
          end
        end

        time = record.delete(@time_key)
        if time.nil?
          time = Fluent::Engine.now
        elsif time.respond_to?(:to_i)
          time = @time_parser.parse(time)
          if time.to_i < 0
            raise RuntimeError, "The #{@time_key}=#{time} is a bad time field"
          end
        else
          raise RuntimeError, "The #{@time_key}=#{time} is a bad time field"
        end

        yield time, record
      end
    end
  end
end
