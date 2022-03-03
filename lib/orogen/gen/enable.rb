# frozen_string_literal: true

module OroGen
    module Gen
        module RTT_CPP
            def self.enable
                Attribute.include AttributeGeneration
                Property.include PropertyGeneration
                Operation.include OperationGeneration
                Port.include PortGeneration
                OutputPort.include OutputPortGeneration
                InputPort.include InputPortGeneration
                TaskContext.prepend TaskContextGeneration
            end
        end
    end
end
