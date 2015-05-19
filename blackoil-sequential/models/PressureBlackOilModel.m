classdef PressureBlackOilModel < ThreePhaseBlackOilModel
    % Two phase oil/water system without dissolution
    properties

    end
    
    methods
        function model = PressureBlackOilModel(G, rock, fluid, varargin)
            
            model = model@ThreePhaseBlackOilModel(G, rock, fluid);

            model = merge_options(model, varargin{:});

            % Ensure simple tolerances
            model.useCNVConvergence = false;
        end
        
        function [problem, state] = getEquations(model, state0, state, dt, drivingForces, varargin)
            [problem, state] = pressureEquationBlackOil(state0, state, model,...
                            dt, ...
                            drivingForces,...
                            varargin{:});
            
        end
        
        function [state, report] = updateState(model, state, problem, dx, drivingForces)
            [state, report] = updateState@ReservoirModel(model, state, problem, dx, drivingForces);
        end
    end
end
