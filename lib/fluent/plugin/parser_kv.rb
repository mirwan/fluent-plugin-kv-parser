module Fluent
  class TextParser
    class KVParser < Parser
      include Configurable
      include TypeConverter

      config_param :kv_delimiter, :string, :default => '/[\t\s]+/'
      config_param :kv_char, :string, :default => '='
      config_param :time_key, :string, :default => 'time'
      config_param :time_format, :string, :default => nil

      def configure(conf={})
        super
        if @kv_delimiter[0] == '/' and @kv_delimiter[-1] == '/'
          @kv_delimiter = Regexp.new(@kv_delimiter[1..-2])
        end
	@time_parser = TimeParser.new(@time_format)
      end

      def parse(text)
        record = {}
        text.split(@kv_delimiter).each do |kv|
          k, v = kv.split(@kv_char, 2)
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

        convert_field_type!(record) if @type_converters
        time = record.delete(@time_key)
        if time.nil?
          time = Engine.now
        else
          time = @time_parser.parse(time)
          if time.to_i < 0
            raise RuntimeError, "The #{@time_key}=#{time} is a bad time field"
          end
        end

        yield time, record
      end

      private

      def convert_field_type!(record)
        @type_converters.each_key { |key|
          if value = record[key]
            record[key] = convert_type(key, value)
          end
        }
      end

    end
    register_template('kv', Proc.new { KVParser.new })
  end
end
