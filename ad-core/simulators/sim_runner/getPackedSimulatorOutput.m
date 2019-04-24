function [ws, states, reports] = getPackedSimulatorOutput(problem, varargin)
    opt = struct('readFromDisk', true, 'readWellSolsFromDisk', true);
    opt = merge_options(opt, varargin{:});
    
    nstep = numel(problem.SimulatorSetup.schedule.step.val);
    
    sh = problem.OutputHandlers.states;
    wh = problem.OutputHandlers.wellSols;
    rh = problem.OutputHandlers.reports;
    
    ndata = sh.numelData();
    [ws, states, reports] = deal(cell(ndata, 1));
    wantWells = false;
    for i = 1:numel(problem.SimulatorSetup.schedule.control)
        ctrl = problem.SimulatorSetup.schedule.control(i);
        if isfield(ctrl, 'W') && ~isempty(ctrl.W)
            wantWells = true;
            break
        end
    end

    sn = sprintf('%s (%s)', problem.BaseName, problem.Name);
    if nstep == ndata
        fprintf('Found complete data for %s: %d steps present\n', sn, ndata);
    elseif ndata > 0
        fprintf('Found partial data for %s: %d of %d steps present\n', sn, ndata, nstep);
    else
        fprintf('Did not find data for %s\n', sn);
    end
    wellOutputMissing = wantWells && wh.numelData() == 0;
    for i = 1:ndata
        if nargout > 1 && opt.readFromDisk
            states{i} = sh{i};
        end
        if wantWells && opt.readWellSolsFromDisk
            if wellOutputMissing
                if isempty(states{i})
                    ws{i} = sh{i}.wellSol;
                else
                    ws{i} = states{i}.wellSol;
                end
            else
                try
                    ws{i} = wh{i};
                catch
                    ws{i} = states{i}.wellSol;
                end
            end
        end
        if nargout > 2 && opt.readFromDisk
            try
                reports{i} = rh{i};
            catch
                reports{i} = [];
            end
        end
    end

    if ~opt.readFromDisk
        % Just return handlers instead
        states = sh;
        reports = rh;
    end
    
    if ~opt.readWellSolsFromDisk
        ws = wh;
    end
end