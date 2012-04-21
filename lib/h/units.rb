# :encoding: utf-8

module H

  module Units

    UNIT_SYN = {
      'm2'=>'m**2',
      'kp/m2'=>'kp/m**2',
      '"'=>:inch,
      '\''=>:ft,
      "''"=>:inch,
      'in'=>:inch
    }

    class <<self

      def valid?(u)
        u = normalize_units(u)
        u && ::Units.u(u) rescue nil
      end

      # Convert a units expression to a Ruby expression valid for units-syste
      def normalize_units(u)
        if u.blank?
          u = nil
        else
          u = u.to_s
          u = UNIT_SYN[u] || u
          u = u.to_s.gsub('^','**').tr(' ','*')
          begin
            ::Units.u(u)
          rescue
            u = nil
          end
        end
        u
      end

      # Convert a units expression to the format to be presented to the user
      def denormalize_units(u)
        if u.blank?
          u = nil
        else
          u = u.to_s.gsub('**','^').tr('*',' ')
        end
        u
      end

    end

  end

  class <<self

    def magnitude_to(v, options={})
      return options[:blank] || '' if v.nil?
      norm_units = options[:units]
      txt = number_to(v, options)
      txt << " #{H::Units.denormalize_units(norm_units)}"
      txt
    end

    def magnitude_from(txt, options={})
      return nil if txt.to_s.strip.empty? || txt==options[:blank]
      norm_units = options[:units]
      if txt.match(/^\s*([0-9\.,+-]+)\s*([a-zA-Z\"\'][a-zA-Z1-3\_\/\*\^\"\']*)\s*$/)
        txt = $1
        from_units = $2 || norm_units
      else
        from_units = norm_units
      end
      from_units = H::Units.normalize_units(from_units)
      raise ArgumentError, "Invalid units for #{norm_units}: #{from_units}}" unless from_units
      v = number_from(txt, options)
      v *= ::Units.u(from_units)
      v.in(norm_units)
    end

  end

end
