# :encoding: utf-8

# Localized formatting for Human-iteraction
module H

  class <<self
    # localized conversions

    # Produce data from human-localized text (from user interface)
    def from(txt, options={})
      type = options[:type] || Float
      type = Float if type==:number
      type = check_type(type)
      if type.ancestors.include?(Numeric)
        number_from(txt, options)
      elsif !(type.instance_methods & [:strftime, 'strftime']).empty?
        date_from(txt, options)
      elsif type==:logical || type==:boolean
        logical_from(txt, options)
      else
        nil
      end
    end

    # Generate human-localized text (for user interface) from data
    def to(value, options={})
      case value
      when Numeric
        number_to(value, options)
      when Time, Date, DateTime
        date_to(value, options)
      when TrueClass, FalseClass
        logical_to(value, options)
      else
        options[:blank] || ''
      end
    end

    def number_to(value, options={})
      options = number_format_options(options).except(:precision).merge(options)
      precision = options[:precision]

      return options[:blank] || '' if value.nil?
      unless value.kind_of?(String)
        value = round(value,precision)
        if value.respond_to?(:nan?) && value.nan?
          return options[:nan] || "--"
        elsif value.respond_to?(:infinite?) && value.infinite?
          inf = options[:inf] || '∞'
          return value<0 ? "-#{inf}" : inf
        else
          value = value.to_i if precision==0
          value = value.to_s
          value = value[0...-2] if value.end_with?('.0')
        end
      # else: TODO recognize nan/infinite values
      end
      if options[:delimiter]
        txt = value.to_s.tr(' ','').tr('.,',options[:separator]+options[:delimiter]).tr(options[:delimiter],'')
      else
        txt = value.to_s.tr(' ,','').tr('.',options[:separator])
      end
      raise ArgumentError, "Invalid number #{txt}" unless /\A[+-]?\d+(?:#{Regexp.escape(options[:separator])}\d*)?(?:[eE][+-]?\d+)?\Z/.match(txt)
      if precision && precision>0
        p = txt.index(options[:separator])
        if p.nil?
          txt << options[:separator]
          p = txt.size - 1
        end
        p += 1
        txt << "0"*(precision-txt.size+p) if txt.size-p < precision
      end
      digit_grouping txt, 3, options[:delimiter], txt.index(/\d/), txt.index(options[:separator]) || txt.size
    end

    def number_from(txt, options={})
      options = number_format_options(options).except(:precision).merge(options)
      type = check_type(options[:type] || (options[:precision]==0 ? Integer : Float))

      return nil if txt.to_s.strip.empty? || txt==options[:blank]

      txt = numbers_to_ruby(txt.tr(' ',''), options)
      raise ArgumentError, "Invalid number #{txt}" unless /\A[+-]?\d+(?:\.\d*)?(?:[eE][+-]?\d+)?\Z/.match(txt)
      if type==Float
        txt.to_f
      elsif type==Integer
        txt.to_i
      else
        type.new txt
      end
    end

    def integer_to(value, options={})
      options = number_format_options(options).merge(options)
      if value.nil?
        options[:blank] || ''
      else
        value = value.to_s
        digit_grouping value, 3, options[:delimiter], value.index(/\d/), value.size
      end
    end

    def integer_from(txt, options={})
      options = number_format_options(options).merge(options)
      if txt.to_s.strip.empty? || txt==options[:blank]
        nil
      else
        txt = txt.tr(' ','')
        txt = txt.tr(options[:delimiter],'') if options[:delimiter]
        txt = txt.tr(options[:separator],'.')
      end
      raise ArgumentError, "Invalid integer #{txt}" unless /\A[+-]?\d+(?:\.0*)?\Z/.match(txt)
      txt.to_i
    end

    def date_to(value, options={})
      return options[:blank] || '' if value.nil?
      I18n.l(value, options)
    end

    def date_from(txt, options={})
      options = number_format_options(options).merge(options)
      type = check_type(options[:type] || Date)

      return nil if txt.to_s.strip.empty? || txt==options[:blank]
      return txt if txt.respond_to?(:strftime)

      translate_month_and_day_names! txt, options[:locale]
      input_formats(type).each do |original_format|
        next unless txt =~ /^#{apply_regex(original_format)}$/

        txt = DateTime.strptime(txt, original_format)
        return Date == type ?
          txt.to_date :
          Time.zone.local(txt.year, txt.mon, txt.mday, txt.hour, txt.min, txt.sec)
      end
      default_parse(txt, type)
    end

    def time_to(value, options={})
      date_to value, options.reverse_merge(:type=>Time)
    end

    def time_from(txt, options={})
      date_from value, options.reverse_merge(:type=>Time)
    end

    def datetime_to(value, options={})
      date_to value, options.reverse_merge(:type=>DateTime)
    end

    def datetime_from(txt, options={})
      date_from value, options.reverse_merge(:type=>DateTime)
    end

    def logical_to(value, options={})
      options = logical_format_options(options).merge(options)
      value.nil? ? options[:blank] : (value ? options[:true] : options[:false])
    end

    def logical_from(txt, options={})
      options = logical_format_options(options).merge(options)
      txt = normalize_txt(txt)
      trues = options[:trues]
      trues ||= [normalize_txt(options[:true])]
      falses = options[:falses]
      falses ||= [normalize_txt(options[:falses])]
      trues.include?(txt) ? true : falses.include?(txt) ? false : nil
    end

    def dms_from(txt, options={})
      original_txt = txt
      options = dms_format_options(options).merge(options)

      return nil if txt.to_s.strip.empty? || txt==options[:blank]

      neg_signs = [options[:south], options[:west]] << '-'
      pos_signs = [options[:north], options[:east]] << '+'
      neg_signs, pos_signs = [neg_signs, pos_signs].map {|signs|
        (signs.map{|s| s.mb_chars.upcase.to_s} + signs.map{|s| s.mb_chars.downcase.to_s}).uniq
      }
      signs = neg_signs + pos_signs
      seps = Array(options[:deg_seps]) + Array(options[:min_seps]) + Array(options[:sec_seps])

      neg = false

      txt = txt.to_s.strip
      neg_signs.each do |sign|
        if txt.start_with?(sign)
          txt = txt[sign.size..-1]
          neg = true
          break
        end
        if txt.end_with?(sign)
          txt = txt[0...-sign.size]
          neg = true
          break
        end
      end
      unless neg
        pos_signs.each do |sign|
          if txt.start_with?(sign)
            txt = txt[sign.size..-1]
            break
          end
          if txt.end_with?(sign)
            txt = txt[0...-sign.size]
            break
          end
        end
      end

      num_options = number_format_options(options).except(:precision).merge(options)
      txt = numbers_to_ruby(txt.strip, num_options)

      default_units = 0

      v = 0
      seps = (seps.map{|s| Regexp.escape(s)}<<"\\s+")*"|"
      scanned_txt = ""
      txt.scan(/((\d+(?:\.\d*)?(?:[eE][+-]?\d+)?)(#{seps})?\s*)/) do |match|
        scanned_txt << match[0]
        number = match[1]
        sep = match[2]
        if Array(options[:deg_seps]).include?(sep)
          units = :deg
        elsif Array(options[:min_seps]).include?(sep)
          units = :min
        elsif Array(options[:sec_seps]).include?(sep)
          units = :sec
        else
          units = DMS_UNITS[default_units]
        end
        raise ArgumentError, "Invalid degrees-minutes-seconds value #{original_txt}" unless units
        default_units = DMS_UNITS.index(units) + 1
        x = number.to_f
        x *= DMS_FACTORS[units]
        v += x
      end
      raise ArgumentError, "Invalid degrees-minutes-seconds value #{original_txt} [#{txt}] [#{scanned_txt}]" unless txt==scanned_txt
      v = -v if neg
      v
    end

    def longitude_to(value, options={})
      dms_to value, options.merge(:longitude=>true)
    end

    def latitude_to(value, options={})
      dms_to value, options.merge(:latitude=>true)
    end

    def dms_to(value, options={})
      longitude = options[:longitude]
      latitude = options[:latitude]
      latitude = true if longitude==false && !options.has_key?(:latitude)
      longitude = true if latitude==false && !options.has_key?(:longitude)
      options = dms_format_options(options).except(:precision).merge(options)
      precision = options[:precision]

      return options[:blank] || '' if value.nil?

      if value.kind_of?(String)
        # TODO: recognize nan/infinite values
        value = value.to_f
      else
        if value.respond_to?(:nan?) && value.nan?
          return options[:nan] || "--"
        elsif value.respond_to?(:infinite?) && value.infinite?
          inf = options[:inf] || '∞'
          return value<0 ? "-#{inf}" : inf
        end
      end
      if value.to_s.start_with?('-') # value<0 # we use to_s to handle negative zero
        value = -value
        neg = true
      end

      deg = value.floor
      value -= deg
      value *= 60
      min = value.floor
      value -= min
      value *= 60
      sec = value.round(SEC_PRECISION)

      txt = []

      txt << integer_to(deg, options.except(:precision)) + Array(options[:deg_seps]).first
      if min>0 || sec>0
        txt << integer_to(min, options.except(:precision)) + Array(options[:min_seps]).first
        if sec>0
          txt << number_to(sec, options) + Array(options[:sec_seps]).first
        end
      end

      txt = txt*" "

      if longitude || latitude
        if longitude
          letter = neg ? options[:west] : options[:east]
        else
          letter = neg ? options[:south] : options[:north]
        end
        txt = options[:prefix] ? "#{letter} #{txt}" : "#{txt} #{letter}"
      else
        txt = "-#{txt}" if neg
      end

      txt
    end

    # TODO: currency, money, bank accounts, credit card numbers, ...

    private
      # include ActionView::Helpers::NumberHelper

      DMS_UNITS = [:deg, :min, :sec]
      DMS_FACTORS = {
        :deg=>1, :min=>1.0/60.0, :sec=>1.0/3600.0
      }
      SEC_EPSILON = 1E-10
      SEC_PRECISION = 10

      def number_format_options(options)
        opt = I18n.translate(:'number.format', :locale => options[:locale])
        opt.kind_of?(Hash) ? opt : {:separator=>'.'}
      end

      def logical_format_options(options)
        opt = I18n.translate(:'logical.format', :locale => options[:locale])
        opt.kind_of?(Hash) ? opt : {:separator=>'.'}
      end

      def dms_format_options(options)
        opt = I18n.translate(:'number.dms.format', :locale => options[:locale])
        opt.kind_of?(Hash) ? opt : {
          :deg_seps => ['°', 'º'],
          :min_seps => "'",
          :sec_seps => '"',
          :north => 'N',
          :south => 'S',
          :east => 'E',
          :west => 'W',
          :prefix => false
        }
      end

      def round(v, ndec)
        return v if (v.respond_to?(:nan?) && v.nan?) || (v.respond_to?(:infinite?) && v.infinite?)
        if ndec
          case v
            when BigDecimal
              v = v.round(ndec)
            when Float
              k = 10**ndec
              v = (k*v).round.to_f/k
          end
        end
        v
      end

      # pos0 first digit, pos1 one past last integral digit
      def digit_grouping(txt,n,sep,pos0,pos1)
        txt[pos0...pos1] = txt[pos0...pos1].gsub(/(\d)(?=(#{'\\d'*n})+(?!\d))/, "\\1#{sep}") if sep
        txt
      end

      # Date-parsing has been taken from https://github.com/clemens/delocalize

      REGEXPS = {
            '%B' => "(#{Date::MONTHNAMES.compact.join('|')})",      # long month name
            '%b' => "(#{Date::ABBR_MONTHNAMES.compact.join('|')})", # short month name
            '%m' => "(\\d{1,2})",                                   # numeric month
            '%A' => "(#{Date::DAYNAMES.join('|')})",                # full day name
            '%a' => "(#{Date::ABBR_DAYNAMES.join('|')})",           # short day name
            '%Y' => "(\\d{4})",                                     # long year
            '%y' => "(\\d{2})",                                     # short year
            '%e' => "(\\s\\d|\\d{2})",                              # short day
            '%d' => "(\\d{1,2})",                                   # full day
            '%H' => "(\\d{2})",                                     # hour (24)
            '%M' => "(\\d{2})",                                     # minute
            '%S' => "(\\d{2})"                                      # second
          }

      def default_parse(datetime, type)
        return if datetime.blank?
        begin
          today = Date.current
          parsed = Date._parse(datetime)
          return if parsed.empty? # the datetime value is invalid
          # set default year, month and day if not found
          parsed.reverse_merge!(:year => today.year, :mon => today.mon, :mday => today.mday)
          datetime = Time.zone.local(*parsed.values_at(:year, :mon, :mday, :hour, :min, :sec))
          Date == type ? datetime.to_date : datetime
        rescue
          datetime
        end
      end

      def translate_month_and_day_names!(datetime, locale=nil)
        translated = I18n.t([:month_names, :abbr_month_names, :day_names, :abbr_day_names], :scope => :date, :locale=>locale).flatten.compact
        original = (Date::MONTHNAMES + Date::ABBR_MONTHNAMES + Date::DAYNAMES + Date::ABBR_DAYNAMES).compact
        translated.each_with_index { |name, i| datetime.gsub!(name, original[i]) }
      end

      def input_formats(type, locale=nil)
        # Date uses date formats, all others use time formats
        type = type == Date ? :date : :time
        I18n.t(:"#{type}.formats", :locale=>locale).slice(*I18n.t(:"#{type}.input.formats", :locale=>locale)).values
      end

      def apply_regex(format)
        format.gsub(/(#{REGEXPS.keys.join('|')})/) { |s| REGEXPS[$1] }
      end

      def normalize_txt(txt)
        txt.mb_chars.normalize(:kd).gsub(/[^\x00-\x7F]/n,'').downcase.strip.to_s
      end

      def check_type(type)
        orig_type = type
        type = type.to_s.camelcase.safe_constantize if type.kind_of?(Symbol)
        raise ArgumentError, "Invalid type #{orig_type}" unless type && type.class==Class
        type
      end

      def numbers_to_ruby(txt, options)
        if options[:delimiter]
          txt = txt.tr(options[:delimiter]+options[:separator], ',.').tr(',','')
        else
          txt = txt.tr(options[:separator], '.')
        end
        txt
      end


  end

end
