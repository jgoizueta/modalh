module H

  # Define methods to_h for H.to, from_h from H.from, xxx_to_h from H.xxx_to, xxx_from_h from H.xxx_from
  module Helpers

    (%w{date number integer logical magnitude}<<nil).each do |type|
      %w{from to}.each do |kind|
        name = [type,kind].compact*'_'
        define_method "#{name}_h" do |*args|
          H.send name, *args
        end
      end
    end

  end

end