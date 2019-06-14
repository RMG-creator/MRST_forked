%% 2D Tutorial For ad Black-Oil-Surfactant system
% The input data is read from a deck using Eclipse format
% (BOSURFACTANT2D.DATA). The surfactant properties (see file surfact.inc) are taken
% from SPE paper 145036.
%
% Surfactant is added to water in order to decrease the surface tension so that,
% in particular, the residual oil is mobilized. See more detail about the
% modeling equations in ad-eor/docs
%
% In this example, water and surfactant are injected at the left-hand side and
% oil is produced at the right-hand side at a given pressure.
%
% In a first period, only water is injected. Then, for a second period,
% surfactant is added to the water.

%% We load the necessary modules

clear
clc
mrstModule add ad-core ad-blackoil ad-eor ad-props deckformat mrst-gui

%% We load the input data and setup the grid, rock and fluid structures

current_dir = fileparts(mfilename('fullpath'));
fn = fullfile(current_dir, 'Test_of_BOSURFACTANT2D.DATA');
% fn = fullfile(current_dir, 'Test_of_SURFACTANT2D.DATA');
% fn = fullfile(current_dir, 'BOSURFACTANT2D.DATA');
gravity on

deck = readEclipseDeck(fn);
deck = convertDeckUnits(deck);

fluid = initDeckADIFluid(deck);
G = initEclipseGrid(deck);
G = computeGeometry(G);
rock  = initEclipseRock(deck);
rock  = compressRock(rock, G.cells.indexMap);

%% Set up the model
% 
% The model object contains the grid, the fluid and rock properties and the
% modeling equations. See simulatorWorkFlowExample.

model = ThreePhaseBlackOilSurfactantModel(G, rock, fluid, ...
                                                  'inputdata', deck, ...
                                                  'extraStateOutput', true);

%% Convert the deck schedule into a MRST schedule by parsing the wells

schedule = convertDeckScheduleToMRST(model, deck);
state0 = initStateDeck(model,deck);
state0.cs    = zeros(G.cells.num, 1);
state0.csmax = state0.cs;

%% Visualize some properties of the model we have setup
%
% We gathered visualizing command for this tutorial in the following script

% example_name = '2D';
% vizSurfactantModel;
% close all;

%% Run the schedule and set up the initial state
%
% We use the function simulateScheduleAD to run the simulation
% Options such as maximum non-linear iterations and tolerance can be set in
% the system struct.
fn = getPlotAfterStep(state0, model, schedule, 'plotWell', true, ...
                      'plotReservoir', false);

[wellSolsSurfactant, statesSurfactant, reportSurfactant] = simulateScheduleAD(state0, model, schedule, 'afterStepFn', fn);

% we use schedulew to run the three phase black oil water flooding simulation.
scheduleW = schedule;
scheduleW.control(1).W(1).cs = 0;
scheduleW.control(1).W(2).cs = 0;
scheduleW.control(2).W(1).cs = 0;
scheduleW.control(2).W(2).cs = 0;
scheduleW.control(3).W(1).cs = 0;
scheduleW.control(3).W(2).cs = 0;
[wellSols, states, report] = simulateScheduleAD(state0, model, scheduleW, 'afterStepFn', fn);
                                       
%% Plot cell oil saturation in different tsteps of surfactant flooding and water flooding

% T = (60:30:300);
% 
% min( cellfun(@(x)min(x.s(:,2)), statesSurfactant) );
% max( cellfun(@(x)max(x.s(:,2)), statesSurfactant) );
% 
% figure
% for i = 1 : length(T)
%     subplot(3,3,i)
%     plotCellData(G, statesSurfactant{T(i)}.s(:,2))
%     plotWell(G, schedule.control(1).W)
%     axis tight
%     colormap(jet)
%     view(3)
%     caxis([0, 0.79])
%     title(['T = ', num2str(T(i))])
% end
% 
% min( cellfun(@(x)min(x.s(:,2)), states) );
% max( cellfun(@(x)max(x.s(:,2)), states) );
% 
% figure
% for i = 1 : length(T)
%     subplot(3,3,i)
%     plotCellData(G, states{T(i)}.s(:,2))
%     plotWell(G, schedule.control(1).W)
%     axis tight
%     colormap(jet)
%     view(3)
%     caxis([0, 0.79])
%     title(['T = ', num2str(T(i))])
% end

%% Plot well solutions

plotWellSols({wellSolsSurfactant, wellSols}, cumsum(schedule.step.val))

%% Copyright notice

% <html>
% <p><font size="-1">
% Copyright 2009-2018 SINTEF Digital, Mathematics & Cybernetics.
% </font></p>
% <p><font size="-1">
% This file is part of The MATLAB Reservoir Simulation Toolbox (MRST).
% </font></p>
% <p><font size="-1">
% MRST is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
% </font></p>
% <p><font size="-1">
% MRST is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
% </font></p>
% <p><font size="-1">
% You should have received a copy of the GNU General Public License
% along with MRST.  If not, see
% <a href="http://www.gnu.org/licenses/">http://www.gnu.org/licenses</a>.
% </font></p>
% </html>

