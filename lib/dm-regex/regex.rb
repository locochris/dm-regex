require 'dm-core'

module DataMapper
  module Regex
    def self.included(model)
      model.extend ClassMethods
    end

    module ClassMethods
      def property(name, type, opts={}, &block)
        regex_property_options.each do |opt|
          if o = opts.delete(opt)
            send("regex_map_#{opt}")[name] = o
          end
        end
        super
      end

      def compile(pattern, options=0)
        @pattern = pattern
        @pat = ::Regexp.compile("#{regex_groups_s}#{pattern}", options)
      end

      def match(buf, relationship=self)
        @pat.match(buf) { |m|
          relationship.first_or_new(regex_match(m))
        }.tap { |obj|
          yield obj if block_given?
        }
      end

      def embedded_pat
        @embedded_pat ||= @pattern.gsub(/\\g<(\w+)>/) { |x|
          name = x[/\\g<(\w+)>/, 1].to_sym
          regex_groups[name]
        }.to_s.gsub(/^\^/, '').gsub(/\$$/, '')
      end

      private

      def relationship_for(name)
        relationships.detect { |r| r.name == name }
      end

      def many_to_one_relationship_names
        @many_to_one_relationship_names ||= relationships.select { |r|
          r.is_a?(DataMapper::Associations::ManyToOne::Relationship)
        }.map(&:name)
      end

      def regex_map_pat
        @regex_map_pat ||= {}
      end

      def regex_map_method
        @regex_map_method ||= {}
      end

      def regex_property_options
        @regex_property_options ||= [:pat, :method]
      end

      def regex_default_pat
        @regex_default_pat ||= /.+?/
      end

      def regex_group_names
        @regex_group_names ||= @pattern.scan(/\\g<(\w+)>/).flatten.map(&:to_sym)
      end

      def regex_groups
        @regex_groups ||= regex_group_names.inject({}) { |h, name|
          h.update(name => regex_pat_for(name))
        }
      end

      def regex_groups_s
        @regex_groups_s ||= regex_groups.inject("") { |str, (name, regex)|
          str << "(?<#{name}>#{regex}){0}"
        }
      end

      def regex_pat_for(name)
        if rel = relationship_for(name)
           rel.parent_model.embedded_pat
        else
          regex_map_pat.fetch(name, regex_default_pat)
        end
      end

      def regex_value_for(name, value)
        if rel = relationship_for(name)
          rel.parent_model.match(value)
        elsif method = regex_map_method[name]
          method.call(value)
        else
          value
        end
      end

      def regex_match(m)
        # TODO refactor this mess
        (properties.map(&:name) + many_to_one_relationship_names).inject({}) { |h, k|
          if regex_group_names.include?(k) || many_to_one_relationship_names.include?(k) && m.names.include?(k)
            h.update(k => regex_value_for(k, m[k]))
          else
            h
          end
        }
      end
    end
  end

  Model.append_inclusions(Regex)
end
