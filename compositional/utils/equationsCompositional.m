function [problem, state] = equationsCompositional(state0, state, model, dt, drivingForces, varargin)
opt = struct('Verbose',     mrstVerbose,...
            'reverseMode', false,...
            'resOnly',     false,...
            'pressure',    false, ...
            'iteration',   -1);

opt = merge_options(opt, varargin{:});

% Shorter names for some commonly used parts of the model and forces.
s = model.operators;
f = model.fluid;
W = drivingForces.W;

fluid = model.fluid;
compFluid = model.EOSModel.fluid;

% state = model.computeFlash(state, dt, opt.iteration);
% Properties at current timestep
[p, sW, z, temp, wellSol] = model.getProps(state, ...
    'pressure', 'water', 'z', 'T', 'wellSol');
assert(all(p>0), 'Pressure must be positive for compositional model');

[p0, sW0, z0, temp0, wellSol0] = model.getProps(state0, ...
    'pressure', 'water', 'z', 'T', 'wellSol');

[qWell, bhp, wellVars, wellVarNames, wellMap] = model.FacilityModel.getAllPrimaryVariables(wellSol);

ncomp = numel(z);
cnames = model.EOSModel.fluid.names;
if model.water
    [p, z{1:ncomp-1}, sW, qWell{:}, bhp, wellVars{:}] = initVariablesADI(p, z{1:ncomp-1}, sW, qWell{:}, bhp, wellVars{:});
    primaryVars = {'pressure', cnames{1:end-1}, 'sW', 'qWs', 'qOs', 'qGs', 'bhp'};
else
    [p, z{1:ncomp-1}, qWell{:}, bhp, wellVars{:}] = initVariablesADI(p, z{1:ncomp-1}, qWell{:}, bhp, wellVars{:});
    primaryVars = {'pressure', cnames{1:end-1}, 'qOs', 'qGs', 'bhp'};
end


z{end} = 1;
for i = 1:(ncomp-1)
    z{end} = z{end} - z{i};
end

[xM,  yM,  sO,  sG,  rhoO,  rhoG, muO, muG] = model.computeTwoPhaseFlowProps(state, p, temp, z);
[xM0, yM0, sO0, sG0, rhoO0, rhoG0] = model.computeTwoPhaseFlowProps(state0, p0, temp0, z0);

% Multipliers for properties
[pvMult, transMult, mobMult, pvMult0] = getMultipliers(model.fluid, p, p0);

if model.water
    sO = (1-sW).*sO;
    sG = (1-sW).*sG;
    sO0 = (1-sW0).*sO0;
    sG0 = (1-sW0).*sG0;
    
    [krW, krO, krG] = model.evaluateRelPerm({sW, sO, sG});
    krW = mobMult.*krW;
else
    [krO, krG] = model.evaluateRelPerm({sO, sG});
end

krO = mobMult.*krO;
krG = mobMult.*krG;

% Compute transmissibility
T = s.T.*transMult;

% Gravity gradient per face
gdz = model.getGravityGradient();

% Oil flux
rhoOf  = s.faceAvg(sO.*rhoO)./max(s.faceAvg(sO), 1e-8);
mobO   = krO./muO;
dpO    = s.Grad(p) - rhoOf.*gdz;
upco  = (double(dpO)<=0);
vO = -s.faceUpstr(upco, mobO).*T.*dpO;

% Gas flux
rhoGf  = s.faceAvg(sG.*rhoG)./max(s.faceAvg(sG), 1e-8);
mobG   = krG./muG;
dpG    = s.Grad(p) - rhoGf.*gdz;
upcg  = (double(dpG)<=0);
vG = -s.faceUpstr(upcg, mobG).*T.*dpG;

rOvO = s.faceUpstr(upco, rhoO).*vO;
rGvG = s.faceUpstr(upcg, rhoG).*vG;

bO = rhoO./fluid.rhoOS;
bG = rhoG./fluid.rhoGS;
% EQUATIONS -----------------------------------------------------------
if model.water
    % Water flux
    muW = f.muW(p);
    bW     = fluid.bW(p);
    rhoW   = bW.*fluid.rhoWS;
    rhoW0 = fluid.bW(p0).*fluid.rhoWS;

    rhoWf  = s.faceAvg(rhoW);
    mobW   = krW./muW;
    dpW    = s.Grad(p) - rhoWf.*gdz;
    upcw  = (double(dpW)<=0);
    vW = -s.faceUpstr(upcw, mobW).*T.*dpW;
    rWvW = s.faceUpstr(upcw, rhoW).*vW;
    water = (s.pv/dt).*( rhoW.*pvMult.*sW - rhoW0.*pvMult0.*sW0 ) + s.Div(rWvW);
else
    [vW, mobW, upcw, bW, rhoW] = deal([]);
end
if model.outputFluxes
    state = model.storeFluxes(state, vW, vO, vG);
end
if model.extraStateOutput
    state = model.storebfactors(state, bW, bO, bG);
    state = model.storeMobilities(state, mobW, mobO, mobG);
    state = model.storeUpstreamIndices(state, upcw, upco, upcg);
    state = model.storeDensities(state, rhoW, rhoO, rhoG);
end


% water equation + n component equations
[eqs, types, names] = deal(cell(1, ncomp + model.water));

if model.water
    eqs{1} = water;
    names{1} = 'water';
    types{1} = 'cell';
    woffset = 1;
else
    woffset = 0;
end

acc = cell(1, ncomp);
for i = 1:ncomp
    names{i+woffset} = compFluid.names{i};
    types{i+woffset} = 'cell';

    acc{i} = (s.pv/dt).*( ...
                    rhoO.*pvMult.*sO.*xM{i} - rhoO0.*pvMult0.*sO0.*xM0{i} + ...
                    rhoG.*pvMult.*sG.*yM{i} - rhoG0.*pvMult0.*sG0.*yM0{i});
    eqs{i+woffset} = acc{i} ...
          + s.Div(rOvO.*s.faceUpstr(upco, xM{i}) + rGvG.*s.faceUpstr(upcg, yM{i}));
    if model.water
        pureWater = double(sW) == 1;
        if any(pureWater)
            % Cells with pure water should just retain their composition to
            % avoid singular systems
            eqs{i+woffset}(pureWater) = eqs{i+woffset}(pureWater) + ...
                            1e-3*(z{i}(pureWater) - double(z{i}(pureWater)));
        end
    end
end


% Finally, add in and setup well equations
if ~isempty(W)
%     wm = model.wellmodel;
    fm = model.FacilityModel;
    if ~opt.reverseMode
        % Store cell wise well variables in cell arrays and send to ewll
        % model to get the fluxes and well control equations.
        
        if model.water
            rho = {rhoW, rhoO, rhoG};
            mob = {mobW, mobO, mobG};
        else
            rho = {rhoO, rhoG};
            mob = {mobO, mobG};
        end
        
        [src, wellsys, state.wellSol] = ...
            fm.getWellContributions(wellSol0, wellSol, qWell, bhp, wellVars, ...
                                    wellMap, p, mob, rho, {}, {}, ...
                                    dt, opt.iteration);
        L_ix = woffset + 1;
        V_ix = woffset + 2;
        
        wc    = vertcat(W.cells);
        w_comp = vertcat(W.components);
        perf2well = getPerforationToWellMapping(W);
        a = w_comp(perf2well, :).*repmat(compFluid.molarMass, numel(wc), 1);
        w_comp = bsxfun(@rdivide, a, sum(a, 2));
        
        x_comp = cellfun(@(v) v(wc), xM, 'UniformOutput', false);
        y_comp = cellfun(@(v) v(wc), yM, 'UniformOutput', false);        
        cqs_m = src.phaseMass;
        injO = double(cqs_m{L_ix}) > 0;
        injG = double(cqs_m{V_ix}) > 0;
        

        offset = numel(wellsys.wellEquations);
        eqs(end+1:end+offset) = wellsys.wellEquations;
        names(end+1:end+offset) = wellsys.names;
        types(end+1:end+offset) = wellsys.types;
        eqs{end+1} = wellsys.controlEquation;
        names{end+1} = 'closureWells';
        types{end+1} = 'well';
        
        if model.water
            % Water
            eqs{1}(wc) = eqs{1}(wc) - cqs_m{1};
        end
        srcTot = 0;
        compSrc = zeros(numel(wc), ncomp);
        for i = 1:ncomp
            ix = i + woffset;
            % Mixture of production and injection. Production uses cell
            % values for components, injectors use whatever was prescribed
            % to the well.
            q_i = (cqs_m{L_ix}.*injO + cqs_m{V_ix}.*injG).*w_comp(perf2well, i)...
                       + ~injO.*x_comp{i}.*cqs_m{L_ix} + ~injG.*y_comp{i}.*cqs_m{V_ix};
            
            eqs{ix}(wc) = eqs{ix}(wc) - q_i;

            compSrc(:, i) = double(q_i);
            srcTot = srcTot + double(q_i);
        end
        fluxt = 0;
        cqr = src.phaseVolume;
        for i = 1:numel(cqr)
            fluxt = fluxt + double(cqr{i});
        end
        for i = 1:numel(W)
            wp = perf2well == i;
            state.wellSol(i).flux = fluxt(wp);
            state.wellSol(i).components = (compSrc(wp, :));
        end
    end
end

if model.water
    wscale = dt./(s.pv*mean(double(rhoW)));
    eqs{1} = eqs{1}.*wscale;
end

if opt.pressure
    if opt.resOnly
        weights = cell(1, ncomp);
        [weights{:}] = deal(1);
    else
        e = vertcat(acc{:});
        e.jac = e.jac(1:ncomp);
        c = cat(e);
        A = c.jac{1};

        ncomp = numel(state.components);
        ncell = numel(state.pressure);
        ndof = ncell*ncomp;% + 3*numel(state.wellSol);

        b = zeros(ndof, 1);
        b(1:ncell) = 1/barsa;

        Ap = A';
        w = Ap\b;
        w = reshape(w, [], ncomp);

        if 1
            weights = cell(ncomp, 1);
            liq = state.L == 1;
            vap = state.L == 0;
            two = ~liq | ~vap;
            for i = 1:ncomp
                weights{i} = liq.*(1./rhoO) + w(:, i).*two + vap.*(1./rhoG);
            end
        end
    end
    peq = 0;
    for i = 1:ncomp
        peq = peq + weights{i}.*eqs{i};
    end
    active = false(numel(primaryVars), 1);
    active(1) = true;
    active(ncomp+1:end) = true;

    eqs{1} = peq;
    
    eqs = eqs(active);
    for i = 1:numel(eqs)
        eqs{i}.jac = eqs{i}.jac(active);
    end
    
    names{1} = 'pressure';


    primaryVars = primaryVars(active);
    names = names(active);
    types = types(active);
end

problem = LinearizedProblem(eqs, types, names, primaryVars, state, dt);

end

%{
Copyright 2009-2016 SINTEF ICT, Applied Mathematics.

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
