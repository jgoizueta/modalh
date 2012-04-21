module H

  # Allow declaration of H conversion for Model attributes like this:
  #
  #   date_h :start
  #   number_h :speed, :precision=>3
  #
  # The first argumet to each declaration is the attribute name; the rest of parameters are passed to the H conversion methods
  module ActiveRecordExtensions

    # Generic H field declarator
    def _h(prefix, attr, *options)

      instance_variable_set :"@#{attr}_h_options", options

      class_eval do

        validates_each attr do |record, attr_name, value|
          record.errors.add attr_name.to_s if record.send(:"#{attr_name}_h_invalid?")
        end

        # attr=(v)
        define_method :"#{attr}=" do |v|
          write_attribute attr, v
          instance_variable_set "@#{attr}_h", nil
        end

        # attr_h
        define_method :"#{attr}_h" do
          # don't cache it, because the locale may change
          # unless instance_variable_defined? "@#{attr}_h"
            instance_variable_set "@#{attr}_h", H.send(:"#{prefix}_to", send(attr), *self.class.instance_variable_get(:"@#{attr}_h_options"))
          # end
          instance_variable_get "@#{attr}_h"
        end

        # attr_h=(txt)
        define_method :"#{attr}_h=" do |txt|
          instance_variable_set "@#{attr}_h", txt
          instance_variable_set "@#{attr}_h_invalid", false
          write_attribute attr, nil
          unless txt.blank?
            begin
               v = H.send(:"#{prefix}_from", txt, *self.class.instance_variable_get(:"@#{attr}_h_options"))
            rescue
               v = nil
            end
            instance_variable_set "@#{attr}_h_invalid", true if v.nil?
          end
          send :"#{attr}=", v
        end

        # attr_h? (returns true if it is valid and not blank)
        define_method :"#{attr}_h?" do
          !instance_variable_get("@#{attr}_h_invalid") && send(:"#{attr}_h")
        end

        # attr_h_invalid?
        define_method :"#{attr}_h_invalid?" do
          instance_variable_get "@#{attr}_h_invalid"
        end

        # attr_h_valid?
        define_method :"#{attr}_h_valid?" do
          !instance_variable_get "@#{attr}_h_invalid"
        end

      end

    end

    [:number, :integer, :date, :logical, :time, :datetime].each do |prefix|
      define_method :"#{prefix}_h" do |attr, *options|
        _h prefix, attr, *options
      end
    end

    # TODO: support special suffix form of units, e.g. _m2 for m^2, for attribute names

    def units_h(name, units, options={})
      norm_units = H::Units.normalize_units(units)
      raise ArgumentError, "invalid units #{units}" unless norm_units
      options[:units] = norm_units
      _h :magnitude, name, options
      short_name = name.to_s.chomp("_#{units}")
      class_eval do
        define_method :"#{short_name}_measure" do
          # ::Units::Measure[send(name), units.to_s]
          v = send(name)
          v && v*::Units.u(norm_units)
        end
        define_method :"#{short_name}_measure=" do |v|
          # Units::Measure[send(name), units.to_s]
          send :"#{name}=", v && v.in(norm_units)
        end
      end
    end

  end

end