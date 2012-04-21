# :encoding: utf-8

module H

  # Helpers to use in ModalFields hooks to automatically generate _h declarations
  # Examples of use
  #
  #   ModalFields.hook do
  #     decimal do |model, declaration|
  #       H::Fields.declare_numeric_field model, declaration
  #     end
  #
  #     float do |model, declaration|
  #       H::Fields.declare_numeric_field model, declaration
  #     end
  #
  #     integer do |model, declaration|
  #       H::Fields.declare_integer_field model, declaration
  #     end
  #   end
  #
  #   ModalFields.hook do
  #     all_fields do |model, declaration|
  #       H::Fields.declare_auto_units_field model, declaration
  #     end
  #   end
  #
  #   ModalFields.hook do
  #     all_fields do |model, declaration|
  #       H::Fields.declare_auto_field_with_units model, declaration
  #     end
  #   end
  #
  module Fields
    class <<self

      # # For numeric types, a display precision different from the stored precision can be selected with
      # # the :h_precision attribute:
      def declare_numeric_field(model, declaration)
        options = declaration.attributes.slice(:precision)
        if precision = declaration.attributes[:h_precision]
          options[:precision] = precision
        end
        declaration.remove_attributes! :h_precision
        model.number_h declaration.name, options
      end

      # Integers can also be assigned a precision and presented as generic numbers
      def declare_integer_field(model, declaration)
        precision = declaration.attributes[:h_precision] || declaration.attributes[:precision] || 0
        declaration.remove_attributes! :h_precision, :precision
        if precision==0
          model.integer_h declaration.name
        else
          model.number_h declaration.name, :precision=>precision
        end
      end

      def declare_units_field(model, declaration, suffix_units=nil)
        options = declaration.attributes.slice(:precision, :units)
        options[:units] ||= suffix_units
        if precision = declaration.attributes[:h_precision]
          options[:precision] = precision
        end
        options[:precision] ||= {'m'=>1, 'mm'=>0, 'cm'=>0, 'km'=>3}[options[:units]] # TODO AppSettings
        declaration.remove_attributes! :h_precision, :units
        model.units_h declaration.name, options[:units], options
      end

      def declare_date_field(model, declaration)
        model.date_h declaration.name
      end

      def declare_time_field(model, declaration)
        model.time_h declaration.name
      end

      def declare_datetime_field(model, declaration)
        model.datetime_h declaration.name
      end

      def declare_boolean_field(model, declaration)
        model.logical_h declaration.name
      end

      # This is handy to be used in all_fields to make any field with a :units parameter or a valid units suffix a units_h field
      # (and make other numberic fields _h too); If a field with a suffix corresponding to valid units should not be a measure,
      # a :units=>nil parameter should be added.
      def declare_auto_units_field(model, declaration)
        if declaration.type==:float || declaration.type==:decimal || declaration.type==:integer
          units = declaration.attributes[:units]
          unless declaration.attributes.has_key?(:units)
            units = declaration.name.to_s.split('_').last
          end
          if units && H::Units.valid?(units)
            declare_units_field model, declaration, units
          else
            raise ArgumentError, "Invalid units #{declaration.attributes[:units]} in declaration of #{model.name}" if declaration.attributes[:units]
            if declaration.type==:integer
              declare_integer_field model, declaration
            else
              declare_numeric_field model, declaration
            end
          end
        end
      end

      def declare_auto_field_with_units(model, declaration)
        case declaration.type
        when :date
          declare_date_field model, declaration
        when :time
          declare_time_field model, declaration
        when :datetime
          declare_datetime_field model, declaration
        when :boolean
          declare_boolean_field model, declaration
        else
          declare_auto_units_field model, declaration
        end
      end

      def declare_auto_field_without_units(model, declaration)
        case declaration.type
        when :date
          declare_date_field model, declaration
        when :time
          declare_time_field model, declaration
        when :datetime
          declare_datetime_field model, declaration
        when :boolean
          declare_boolean_field model, declaration
        when :integer
          declare_integer_field model, declaration
        when :float, :decimal
          declare_numeric_field model, declaration
        end
      end

    end
  end
end