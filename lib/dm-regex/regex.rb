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
        # TODO clean up this one
#p @pat, buf
        scanable_pat  # TODO remove the need to call this here
        if is_parent?
#p 'is_parent'
          m = @pat.match(buf)
          first_or_new(regex_match(m)).tap { |obj|
            # TODO iterate through :one_to_manys ... hard :(
            one_to_many = buf[scanable_pat, :one_to_many]
            # TODO iterate through children
            scanning_pat = /(?<#{:word}>#{regex_groups[:word]})/ # XXX :word is hard-coded here
            one_to_many.scan(scanning_pat).map(&:first).each do |sub_buf|
              Word.match(sub_buf, obj.words)
            end
          }
        else
          @pat.match(buf) { |m|
            relationship.first_or_new(regex_match(m))
          }.tap { |obj|
            yield obj if block_given?
          }
        end
      end

      def embedded_pat
        @embedded_pat ||= regex_str_to_regex(
          @pattern.gsub(/\\g<(\w+)>/) { |x|
            name = x[/\\g<(\w+)>/, 1].to_sym
            regex_groups[name]
          }.to_s.gsub(/^\^/, '').gsub(/\$$/, '')
        )
      end

      def scanable_pat
        regex_from_string_pat = /^\(\?[-mix]+:(.*)\)$/m
        one_to_many_pat = /(?<brace_expression>\(([^()]|\g<brace_expression>)*\)\+)/
        Regexp.compile(
          @pat.to_s.gsub(one_to_many_pat) { |m|
            @is_parent = true
            "(?<one_to_many>#{m})"
          }[regex_from_string_pat, 1],
          @pat.options
        )
      end

      private

      def is_parent?
        @is_parent
      end

      def regex_property_options
        @regex_property_options ||= [:pat, :method]
      end

      def relationship_for(name)
        relationships.detect { |r| r.name == name }
      end

      def many_to_one_relationship_names
        @many_to_one_relationship_names ||= relationships.select { |r|
          r.is_a?(DataMapper::Associations::ManyToOne::Relationship)
        }.map(&:name)
      end

      def one_to_many_relationship_names
        @one_to_many_relationship_names ||= relationships.select { |r|
          r.is_a?(DataMapper::Associations::OneToMany::Relationship)
        }.map(&:name)
      end

      def relationship_names
        @relationship_names ||= relationships.map(&:name)
      end

      def regex_map_pat
        @regex_map_pat ||= {}
      end

      def regex_map_method
        @regex_map_method ||= {}
      end

      def regex_default_pat
        @regex_default_pat ||= /.+?/
      end

      def regex_group_names(_pat=@pattern)
        @regex_group_names ||= _pat.scan(/\\g<(\w+)>/).flatten.map(&:to_sym)
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

      def regex_str_to_regex(regex_str)
        Regexp.compile(
         regex_str.gsub(/\(\?\-[mix]*:(.*?)\)/) { |x| x[/\(\?\-[mix]*:(.*)\)/, 1] }
        )
      end

      def regex_pat_for(name)
        if rel = relationship_for(name)
           rel.parent_model.embedded_pat
        elsif rel = relationship_for(DataMapper::Inflector.pluralize(name).to_sym)
           rel.child_model.embedded_pat
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
        (properties.map(&:name) + relationship_names).inject({}) { |h, k|
#puts "YYY: #{k.inspect}, #{relationship_names.inspect}, #{m.names.inspect}"
          if regex_group_names.include?(k) ||
          relationship_names.include?(k) && m.names.include?(k) ||
          properties.map(&:name).include?(k) && m.names.include?(k.to_s)
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
