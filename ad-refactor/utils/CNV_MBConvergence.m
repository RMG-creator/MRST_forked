function [converged, values] = CNV_MBConvergence(model, problem)
    % Compute convergence based on total mass balance and maximum residual mass balance.
    %
    % SYNOPSIS:
    %   [converged, values] = CNV_MBConvergence(model, problem)
    %
    % DESCRIPTION:
    %   Compute CNV/MB type convergence similar to what is used for black
    %   oil convergence in commercial simulators.
    %
    % REQUIRED PARAMETERS:
    %   model      - Subclass of PhysicalModel. Strongly suggested to be
    %                some black oil variant, as this convergence function
    %                does *not* account for general residual convergence.
    %
    %   problem    - LinearizedProblem class instance we want to test for
    %                convergence.
    %
    %
    % RETURNS:
    %   convergence - Boolean indicating if the state used to produce the 
    %                 LinearizedProblem has converged.
    %                  
    %   values      - 1 by 6 array containing mass balance in the first
    %                 three terms followed by cnv in the last three. The
    %                 phase ordering is assumed to be oil, water, gas.
    %                 Phases present will return a zero in their place.
 
    %{
    Copyright 2009-2014 SINTEF ICT, Applied Mathematics.

    This file is part of The MATLAB Reservoir Simulation Toolbox (MRST).

    MRST is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    MRST is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with MRST.  If not, see <http://www.gnu.org/licenses/>.
    %}

    fluid = model.fluid;
    state = problem.state;
    nc = model.G.cells.num;
    pv = model.operators.pv;
    pvsum = sum(pv);

    % Grab tolerances
    tol_mb = model.toleranceMB;
    tol_cnv = model.toleranceCNV;

    if model.water,
        BW = 1./fluid.bW(state.pressure);
        RW = double(problem.equations{problem.indexOfEquationName('water')});
        BW_avg = sum(BW)/nc;
        CNVW = BW_avg*problem.dt*max(abs(RW)./pv);
    else
        BW_avg = 0;
        CNVW   = 0;
        RW     = 0;
    end

    % OIL
    if model.oil,
        if model.disgas
            % If we have liveoil, BO is defined not only by pressure, but
            % also by oil solved in gas which must be calculated in cells
            % where gas saturation is > 0.
            BO = 1./fluid.bO(state.pressure, state.rs, state.s(:, 3)>0);
        else
            BO = 1./fluid.bO(state.pressure);
        end
        RO = double(problem.equations{problem.indexOfEquationName('oil')});
        BO_avg = sum(BO)/nc;
        CNVO = BO_avg*problem.dt*max(abs(RO)./pv);
    else
        BO_avg = 0;
        CNVO   = 0;
        RO     = 0;
    end

    % GAS
    if model.gas,
        if model.vapoil
            BG = 1./fluid.bG(state.pressure, state.rv, state.s(:,2)>0); % need to fix index...
        else
            BG = 1./fluid.bG(state.pressure);
        end
        RG = double(problem.equations{problem.indexOfEquationName('gas')});
        BG_avg = sum(BG)/nc;
        CNVG = BG_avg*problem.dt*max(abs(RG)./pv);
    else
        BG_avg = 0;
        CNVG   = 0;
        RG     = 0;
    end

    % Check if material balance for each phase fullfills residual
    % convergence criterion
    MB = abs([BO_avg*sum(RO), BW_avg*sum(RW) BG_avg*sum(RG)]);
    converged_MB  = all(MB < tol_mb*pvsum/problem.dt);

    % Check maximum normalized residuals (maximum mass error)
    CNV = [CNVO CNVW CNVG] ;
    converged_CNV = all(CNV < tol_cnv);



    converged = converged_MB & converged_CNV;
    values = [CNV, MB];
    
    if mrstVerbose()
        if problem.iterationNo == 1
            fprintf('CNVO\t\tCNVW\t\tCNVG\t\tMBO\t\tMBW\t\tMBG\n');
        end
        fprintf('%2.2e\t', values);
        fprintf('\n')
    end
end
