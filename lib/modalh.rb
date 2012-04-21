require 'h/h'
require 'h/units'
require 'h/helpers'
require 'h/active_record_extensions'
require 'h/fields'

# Define xxxx_h field declarators for Model classes
if defined?(ActiveRecord::Base)
  ActiveRecord::Base.extend H::ActiveRecordExtensions
end

# Add controller & view xxx_to_h/xxx_from_h helpers
if defined?(ActionController::Base)
   class ActionController::Base
     include H::Helpers
   end
   ActionController::Base.helper_method *H::Helpers.instance_methods
end

# Make same helpers accessible with the H prefix from elsewhere
# (not really needed; can use H.to/H.from instead)
H.extend H::Helpers
