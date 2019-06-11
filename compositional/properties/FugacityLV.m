classdef FugacityLV < StateFunction
    properties
        useCompactEvaluation = true;
    end
    
    methods
        function gp = FugacityLV(model, varargin)
            gp@StateFunction(model, varargin{:});
            gp = gp.dependsOn({'PhaseMixingCoefficients', 'ComponentPhaseMoleFractions', 'PhaseCompressibilityFactors'});
        end

        function f = evaluateOnDomain(prop, model, state)
            eos = model.EOSModel;
            p = model.getProps(state, 'pressure');
            [mix, mf, Z] = prop.getEvaluatedDependencies(state, 'PhaseMixingCoefficients', 'ComponentPhaseMoleFractions', 'PhaseCompressibilityFactors');
            
            ncomp = numel(eos.fluid.names);
            f = cell(ncomp, 2);
            wat = model.water;
            for i = 1:2
                xy = mf((1+wat):end, i + wat)';
                m = mix{i+wat};
                if i == 2 && prop.useCompactEvaluation
                    [~, ~, twoPhase] = model.getFlag(state);
                    fi = f(:, 1);
                    
                    xy = cellfun(@(x) x(twoPhase), xy, 'UniformOutput', false);
                    Si = cellfun(@(x) x(twoPhase), m.Si, 'UniformOutput', false);
                    Bi = cellfun(@(x) x(twoPhase), m.Bi, 'UniformOutput', false);
                    f_2ph = model.EOSModel.computeFugacity(p(twoPhase), xy, Z{i+wat}(twoPhase), m.A(twoPhase), m.B(twoPhase), Si, Bi);
                    for j = 1:numel(fi)
                        fi{j}(twoPhase) = f_2ph{j};
                    end
                    f(:, i) = fi;
                else
                    f(:, i) = model.EOSModel.computeFugacity(p, xy, Z{i+wat}, m.A, m.B, m.Si, m.Bi);
                end
            end
        end
    end
end