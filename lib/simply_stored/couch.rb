require 'simply_stored/couch/validations'
require 'simply_stored/couch/belongs_to'
require 'simply_stored/couch/has_many'
require 'simply_stored/couch/ext/couch_potato'

module SimplyStored
  module Couch
    def self.included(clazz)
      clazz.class_eval do
        include CouchPotato::Persistence
        include InstanceMethods
        extend ClassMethods
      end
    end
    
    module InstanceMethods
      def ==(other)
        other._id == _id && other._rev == _rev
      end

      def eql?(other)
        self.==(other)
      end

      def save(validate = true)
        CouchPotato.database.save_document(self)
      end

      def save!
        CouchPotato.database.save_document!(self)
      end

      def destroy
        CouchPotato.database.destroy_document(self)
      end

      def update_attributes(attributes = {})
        self.attributes = attributes
        save
      end
    end
    
    module ClassMethods
      include SimplyStored::ClassMethods::Base
      include SimplyStored::Couch::Validations
      include SimplyStored::Couch::BelongsTo
      include SimplyStored::Couch::HasMany
      
      def create(attributes = {})
        instance = new(attributes)
        instance.save
        instance
      end
      
      def find(*args)
        case what = args.pop
        when :all
          CouchPotato.database.view(all, *args)
        else
          CouchPotato.database.load_document(what)
        end
      end
      
      def method_missing(name, *args)
        if name.to_s =~ /^find_by/
          keys = name.to_s.gsub(/^find_by_/, "").split("_and_")
          view_name = name.to_s.gsub(/^find_/, "").to_sym
          puts "Warning: Defining view #{view_name} at call time, please add it to the class body. (Called from #{caller[0]})"
          view view_name, :key => keys
          self.class.instance_eval do
            define_method(name) do
              CouchPotato.database.view(send(view_name, :key => args))
            end
          end
          send(name, args)
        else
          super
        end
      end
    end
  end
end