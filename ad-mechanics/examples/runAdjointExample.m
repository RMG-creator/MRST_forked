%% Computation of Adjoints for Lift values
%
%
% In this example, we setup a poroelastic simulation and demonstrate how one can
% setup adjoint simulations to compute gradients (sensitivities) of a given
% quantity.
%
% In this case, we look at the uplift (vertical displacement) at the
% top of the domain.
%

mrstModule add ad-mechanics ad-core ad-props ad-blackoil vemmech deckformat mrst-gui

%% Setup geometry
%

% We consider a  2D regular cartesian domain

cartDim = [31, 30];
L       = [30, 10];
G = cartGrid(cartDim, L);
G = computeGeometry(G);


%% Setup fluid
%

% We can consider different fluid models

opt.fluid_model = 'single phase';
pRef = 100*barsa;
switch opt.fluid_model
  case 'single phase'
    fluid = initSimpleADIFluid('phases', 'W', 'mu', 1*centi*poise, 'rho', ...
                               1000*kilogram/meter^3, 'c', 1e-4, 'cR', ...
                               4e-10, 'pRef', pRef);
  case 'oil water'
    fluid = initSimpleADIFluid('phases', 'WO', 'mu', [1, 100]*centi*poise, 'n', ...
                               [1, 1], 'rho', [1000, 700]*kilogram/ meter^2, 'c', ...
                               1e-10*[1, 1], 'cR', 1e-10, 'pRef', pRef);
  case 'blackoil'
    error('not yet implemented, but could be easily done!')
  otherwise
    error('fluid_model not recognized.')
end



%% Setup rock parameters (for flow)
%

rock.perm = darcy*ones(G.cells.num, 1);
rock.poro = 0.3*ones(G.cells.num, 1);


%% Setup material parameters for Biot and mechanics
%

E          = 1e-2*giga*Pascal; % Young's module
nu         = 0.3;              % Poisson's ratio
alpha      = 1;                % Biot's coefficient
% Convert global properties to cell values
E          = repmat(E, G.cells.num, 1);
nu         = repmat(nu, G.cells.num, 1);
rock.alpha = repmat(alpha, G.cells.num, 1);


%% Setup boundary conditions for mechanics (no displacement)
%
%
% zero displacement at bottom, left and right sides. We impose a given pressure
% at the top.

% Gather the Dirichlet boundary faces (zero displacement) at left, bottom and right.
dummyval = 100; % We use pside to recover face at bottom, we use a dummy
                % value for pressure in this function.
bc = pside([], G, 'Xmin', dummyval);
bc = pside(bc, G, 'Xmax', dummyval);
bc = pside(bc, G, 'Ymin', dummyval);
indfacebc = bc.face;

% Get the nodes that belong to the Dirichlet boundary faces.
facetonode = accumarray([G.faces.nodes, rldecode((1 : G.faces.num)', ...
                                                 diff(G.faces.nodePos))], ...
                        ones(numel(G.faces.nodes), 1), [G.nodes.num, ...
                    G.faces.num]);
isbcface = zeros(G.faces.num, 1);
isbcface(indfacebc) = 1;
bcnodes  = find(facetonode*isbcface);
nn       = numel(bcnodes);
u        = zeros(nn, G.griddim);
m        = ones(nn,  G.griddim);
disp_bc  = struct('nodes', bcnodes, 'uu', u, 'mask', m);

% Set a given pressure on the  face at the top.
dummyval = 100; % We use pside to recover face at bottom, we use a dummy
                % value for pressure in this function.
bc = pside([], G, 'Ymax', dummyval);
sidefaces = bc.face;
signcoef = (G.faces.neighbors(sidefaces, 1) == 0) - (G.faces.neighbors(sidefaces, ...
                                                  2) == 0);
n = bsxfun(@times, G.faces.normals(sidefaces, :), signcoef./ ...
           G.faces.areas(sidefaces));
force = bsxfun(@times, n, pRef);
force_bc = struct('faces', sidefaces, 'force', force);

% Construct the boundary conidtion structure for the  mechanical system
el_bc = struct('disp_bc' , disp_bc, 'force_bc', force_bc);


%% Setup volumetric load for mechanics
%
% In this example we do not impose any volumetric force
loadfun = @(x) (0*x);


%% Gather all the mechanical parameters in a struct
%

mech = struct('E', E, 'nu', nu, 'el_bc', el_bc, 'load', loadfun);


%% Set gravity off
%

gravity off


%% Setup model
%

switch opt.fluid_model
  case 'single phase'
    model = MechWaterModel(G, rock, fluid, mech, 'verbose', true);
  case 'oil water'
    model = MechOilWaterModel(G, rock, fluid, mech, 'verbose', true);
  case 'blackoil'
    error('not yet implemented')
  otherwise
    error('fluid_model not recognized.')
end


%% Set up initial reservoir state
%

clear initState;
% The initial fluid pressure is set to a constant;
initState.pressure = pRef*ones(G.cells.num, 1);
switch opt.fluid_model
  case 'single phase'
    init_sat = [1];
  case 'oil water'
    init_sat = [0, 1];
  case 'blackoil'
    error('not yet implemented')
    % init_sat = [0, 1, 0];
    % initState.rs  = 0.5*fluid.rsSat(initState.pressure);
  otherwise
    error('fluid_model not recognized.')
end
% set up initial saturations
initState.s  = ones(G.cells.num, 1)*init_sat;
initState.xd = zeros(nnz(~model.mechModel.operators.isdirdofs), 1);
% We compute the corresponding displacement field using the dedicated
% function computeInitDisp
initState    = computeInitDisp(model, initState, [], 'pressure', initState.pressure);
initState    = addDerivedQuantities(model.mechModel, initState);


%% Setup the wells
%

nx = G.cartDims(1);
ny = G.cartDims(2);
switch opt.fluid_model
  case 'single phase'
    comp_inj  = [1];
    comp_prod = [1];
  case 'oil water'
    comp_inj  = [1, 0];
    comp_prod = [0, 1];
  case 'blackoil'
    error('not yet implemented')
  otherwise
    error('fluid_model not recognized.')
end

W = [];
wellopt = {'type', 'rate', 'Sign', 1, 'comp_i', comp_inj};
% Two injection wells vertically aligned, near the bottom
W = addWell(W, G, rock, round(nx/4)   + floor(1/4*ny)*nx, wellopt{:});
W = addWell(W, G, rock, nx + 1 - round(nx/4) + floor(1/4*ny)*nx, wellopt{:});
% production well in the center
wellopt = {'type', 'bhp', 'val', pRef, 'Sign', -1, 'comp_i', comp_prod};
W = addWell(W, G, rock, round(nx/2)   + floor(1/4*ny)*nx, wellopt{:});

% We plot the well location
wellcells = zeros(G.cells.num, 1);
wellcells(W(1).cells) = 1;
wellcells(W(2).cells) = 1;
wellcells(W(3).cells) = 2;
figure
clf
plotCellData(G, wellcells);
comment = ['The connection of the wells are colored' char(10) 'We have two ' ...
          'injection wells and on production well'];
text(0.5, 0.9, comment, 'units', 'normalized', 'horizontalalignment', 'center', ...
     'backgroundcolor', 'white');

% We incorporate the well in a FacilityModel which takes care of coupling all
% the well equations with the reservoir equations

facilityModel = FacilityModel(model.fluidModel);
facilityModel = facilityModel.setupWells(W);
model.FacilityModel = facilityModel;
model = model.validateModel(); % setup consistent fields for model (in
                               % particular the facility model for the fluid
                               % submodel)

%% Setup a schedule
%
%
% We set up a schedule where we gradually decrease from a maximum to a minimum
% injection rate value. Then, we keep the injection rate constant

clear schedule
schedule.step.val     = [1*day*ones(1, 1); 10*day*ones(30, 1)];
nsteps = numel(schedule.step.val);
schedule.step.control = (1 : nsteps)';
valmax = 1*meter^3/day;
valmin = 1e-1*meter^3/day;
ctime = cumsum(schedule.step.val);
flattentime   = 150*day; % Time when we reach the minimal rate value
qW = zeros(nsteps, 1);
for i = 1 : numel(schedule.step.control)
    if ctime(i) < flattentime
        qW(i) = valmin*ctime(i)/flattentime + valmax*(flattentime - ctime(i))/flattentime;
    else
        qW(i) = valmin;
    end
    W(1).val = qW(i);
    W(2).val = qW(i);
    schedule.control(i) = struct('W', W);
end
% We plot the injection schedule
figure
plot(ctime/day, qW*day);
axis([0, ctime(end)/day, 0, 1])
title('Injection rate (m^3/day)');
xlabel('time (day)')


%% Run the schedule
%

[wellSols, states] = simulateScheduleAD(initState, model, schedule);

% We start visualization tool to inspect the result of the simulation
figure
plotToolbar(G, states);
colorbar


%% We plot the evolution of the uplift
%

% Get index of a node belonging to the cell at the middle on the top layer.
topcell = floor(nx/2) + nx*(ny - 1);
topface = G.cells.faces(G.cells.facePos(topcell) : (G.cells.facePos(topcell + ...
                                                  1)  - 1), :);
topface = topface(topface(:, 2) == 4, 1);
topnode = G.faces.nodes(G.faces.nodePos(topface)); % takes one node from the
                                                   % top face (the first listed)

laststep = numel(states);
uplift = @(step) (computeUpliftForState(model, states{step}, topnode));
uplifts = @()(arrayfun(uplift, (1 : laststep)'));
figure
plot(ctime/day, uplifts(), 'o-');
title('uplift values');
xlabel('time (in days)');


%% Setup of the objective function given by averaged uplift values
%
% The adoint framework is general and computes the derivative of a (scalar)
% objective function of following forms,
%
%       obj = sum_{time step i = 1,..., last} (obj_i(state at time step i))
%
% This special form of this objective function allows for a recursive computation
% of the adjoint variables.
%
% We set up our objective function as being a time average of weighted uplift in
% a node in the middle at the top
%
% Given an exponent p, we take
%
%      obj = sum_{time step i = 1, ..., las} ( dt(i) * uplift(i) ^ p )
%
% See function objUpliftAver.
%



%% Compute gradients using the adjoint formulation for different exponent

exponent = 1; % corresponds to the classical average
C = 1e3; % For large exponent we need to scale the values to avoid very large
         % or very small objective function
objUpliftFunc = @(tstep) objUpliftAver(model, states, schedule, topnode, ...
                                       'tStep', tstep, 'computePartials', true, ...
                                       'exponent', exponent, ...
                                       'normalizationConstant', C);
adjointGradient1 = computeGradientAdjointAD(initState, states, model, schedule, objUpliftFunc);


%% We choose a large exponent values
%
% For the injection values we have chosen, the uplift is first increasing and
% then decreasing.
%
% Let us imagine that we want to control this uplift and find injection rates
% which will, for example, reduce this uplift.  We need to run an optimization
% algorithm and we are interested to get the derivative of the uplift
% function. By choosing a large exponent in the average sum of the uplift values
% (see comments above), we increase the sensitivity of the objective function
% with respect to the maximal values.

exponent = 100; % Large exponent value

C = 1e3; % For large exponent we need to scale the values to avoid very large
         % or very small objective function
objUpliftFunc = @(tstep) objUpliftAver(model, states, schedule, topnode, ...
                                       'tStep', tstep, 'computePartials', true, ...
                                       'exponent', exponent, ...
                                       'normalizationConstant', C);
adjointGradient2 = computeGradientAdjointAD(initState, states, model, schedule, objUpliftFunc);

% Note that we can change the objective function and compute the derivative
% *without* run the simulation again.

figure
clf
plot(ctime/day, uplifts(), 'o-');
ylabel('uplift values');
xlabel('time (in days)');
hold on
yyaxis right

grads1 = cell2mat(adjointGradient1);
qWgrad1 = grads1(1, :);
% we renormalize the gradients to compare the two series of values (p=1, p=100)
qWgrad1 = 1/max(qWgrad1)*qWgrad1;
plot(ctime/day, qWgrad1, '*-');

grads2 = cell2mat(adjointGradient2);
qWgrad2 = grads2(2, :);
qWgrad2 = 2/max(qWgrad2)*qWgrad2;
plot(ctime/day, qWgrad2, '*-');

ylabel('gradient value')
legend('uplift value', 'exponent = 1', 'exponent = 100');

%% Comparison between the two exponents
%
%
% The derivatives of the objective function computed for p=100 have a peak in
% the region where the uplift is maximum. In an optimization framework, by
% modifying correspondingly the injection values, we can expect to reduce the
% amplitude of this maximum uplift.


%% We can check the results from the adjoint computation by using finite difference
%
%
% The function computeGradientAdjointAD sets up this computation for us.  It
% should be used with a smaller schedule, otherwise the computation is very
% long.

compute_numerical_derivative = false;
if compute_numerical_derivative
    objUpliftFunc2 = @(wellSols, states, schedule) objUplift(model, states, ...
                                                      schedule, topnode, ...
                                                      'computePartials', ...
                                                      false);
    fdgrad = computeGradientPerturbationAD(initState, model, schedule, ...
                                           objUpliftFunc2, 'perturbation', ...
                                           1e-7);
end
