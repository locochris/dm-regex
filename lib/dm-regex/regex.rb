require 'dm-core'

module DataMapper
  module Regex
    def self.included(model)
      model.extend ClassMethods
    end

    module ClassMethods
      attr_reader :pat

      def compile(pattern, options=0)
        @group_names = pattern.scan(/\\g<(\w+)>/).flatten.map(&:to_sym)
        @pat = ::Regexp.compile("#{groups}#{pattern}", options)
      end

      def match(buf, parent=self)
        pat.match(buf) { |m| parent.first_or_new(attrs_from_match(m)) }.tap { |obj|
          yield obj if block_given?
        }
      end

      def property(name, type, opts={}, &block)
        if group_pat = opts.delete(:pat)
          map_pat[name] = group_pat
        end
        if group_method = opts.delete(:method)
          map_method[name] = group_method
        end
        super
      end

      private

      def map_pat
        @map_pat ||= {}
      end

      def map_method
        @map_method ||= {}
      end

      def map_value(name, value)
        value
      end

      def groups
        @groups ||= @group_names.inject("") { |str, name|
          str << "(?<#{name}>#{map_pat.fetch(name, '.+?')}){0}"
        }
      end

      def attrs_from_match(m)
        properties.map(&:name).inject({}) { |h, k|
          if @group_names.include?(k)
            value = m[k]
            if method = map_method[k]
              value = method.call(value)
            end
            h.update(k => value)
          else
            h
          end
        }
      end
    end
  end

  Model.append_inclusions(Regex)
end
