module SimplyStored
  module Couch
    module HasMany
      def has_many(name, options = {})
        property name, :class => SimplyStored::Couch::HasMany::Property
      end
      
      def define_has_many_setter_add(name)
        define_method("add_#{name.to_s.singularize}") do |value|
          klass = self.class.get_class_from_name(name)
          raise ArgumentError, "expected #{klass} got #{value.class}" unless value.is_a?(klass)
          
          value.send("#{self.class.foreign_key}=", id)
          value.save
          cached_version = instance_variable_get("@#{name}") || []
          instance_variable_set("@#{name}", cached_version << value)
        end
      end

      def define_has_many_setter_remove(name)
        define_method "remove_#{name.to_s.singularize}" do |value|
          klass = self.class.get_class_from_name(name)
          raise ArgumentError, "expected #{klass} got #{value.class}" unless value.is_a?(klass)
          raise ArgumentError, "cannot remove not mine" unless value.send(self.class.foreign_key.to_sym) == id
          
          value.send("#{self.class.foreign_key}=", nil) 
          value.save
          cached_version = instance_variable_get("@#{name}") || []
          instance_variable_set("@#{name}", cached_version.delete_if{|item| item.id == value.id})
        end
      end
      
      def define_has_many_setter_remove_all(name)
        define_method "remove_all_#{name}" do
          all = send("#{name}", :force_reload => true)
          
          all.collect{|i| i}.each do |item|
            send("remove_#{name.to_s.singularize}", item)
          end
        end
      end
      
      class Property
        attr_reader :name
        
        def initialize(owner_clazz, name, options = {})
          @name = name
          owner_clazz.class_eval do
            def find_associated(from, to)
              CouchPotato.database.view(
                self.class.get_class_from_name(from).send(
                  "association_#{from.to_s.singularize}_belongs_to_#{to.name.downcase}", :key => id))
            end unless instance_methods.grep(/^find_associated$/).any?
            
            define_method(name) do |*args|
              forced_reload = args.first && args.first.is_a?(Hash) && args.first[:force_reload]
              if forced_reload || instance_variable_get("@#{name}").nil?
                instance_variable_set("@#{name}", find_associated(name, owner_clazz))
              end
              instance_variable_get("@#{name}")
            end
            
            define_has_many_setter_add(name)
            define_has_many_setter_remove(name)
            define_has_many_setter_remove_all(name)
          end
        end
        
        def save(object)
        end

        def dirty?(object)
          false
        end

        def destroy(object)
        end

        def build(object, json)
        end

        def serialize(json, object)
        end
        
        def supports_dirty?
          false
        end
      end
    end
  end
end