classdef PhysicalModel
    % Base class for all AD models. Implements a generic discretized model.
    %
    % SYNOPSIS:
    %
    %   model = PhysicalModel(G)
    %
    % DESCRIPTION:
    %   Base class for implementing physical models for use with automatic
    %   differentiation. This class cannot be used directly.
    %
    %   A physical model consists of a set of discrete operators that can be
    %   used to define the model equations and a nonlinear tolerance that
    %   defines how close the values must be to zero before the equations can
    %   be considered to be fulfilled. In most cases, the operators are defined
    %   over a grid, which is an optional property in this class. In addition,
    %   the class contains a flag informing if the model equations are linear,
    %   and a flag determining verbosity of class functions.
    %
    %   The class contains member functions for:
    %
    %     - evaluating residual equations and Jacobians
    %     - querying and setting individual variables in the physical state
    %     - executing a single nonlinear step (i.e., a linear solve with a
    %       possible subsequent stabilization step), verifying convergence, and
    %       reporting the status of the step
    %     - verifying the model, associated physical states, or individual
    %       physical properties
    %
    %   as well as a number of utility functions for updating the physical
    %   state with increments from the linear solve, etc. See the
    %   implementation of the class for more details.
    %
    % PARAMETERS:
    %   G - Simulation grid. Can be set to empty.
    %
    % OPTIONAL PARAMETERS:
    %   'property' - Set property to the specified value.
    %
    % RETURNS:
    %   model - Class instance of `PhysicalModel`.
    %
    % NOTE:
    %  This is the standard base class for the AD-OO solvers. As such, it
    %  does not implement any specific discretization or equations and is
    %  seldom instansiated on its own.
    %
    % SEE ALSO:
    %   `ReservoirModel`, `ThreePhaseBlackOilModel`,
    %   `TwoPhaseOilWaterModel`
    
properties
    operators % Operators used for construction of systems
    nonlinearTolerance % Inf norm tolerance for checking residuals
    G % Grid. Can be empty.
    verbose % Verbosity from model routines
    stepFunctionIsLinear % Model step function is linear.
    % This means that the framework assumes the model is guaranteed to
    % converge in a single step.  Do not enable this unless you are very
    % certain that it is the case, as this removes several tolerance
    % checks.
end

methods
    function model = PhysicalModel(G, varargin)
        model.nonlinearTolerance = 1e-6;
        model.verbose = mrstVerbose();
        model = merge_options(model, varargin{:});
        model.G = G;

        model.stepFunctionIsLinear = false;
    end

    
    function [problem, state] = getEquations(model, state0, state, dt, forces, varargin)
        % Get the set of linearized model equations with possible Jacobians
        %
        % SYNOPSIS:
        %   [problem, state] = model.getEquations(state0, state, dt, drivingForces)
        %
        % DESCRIPTION:
        %   Provide a set of linearized equations. Unless otherwise noted,
        %   these equations will have `ADI` type, containing both the value
        %   and Jacobians of the residual equations.
        %
        % PARAMETERS:
        %   model         - Class instance
        %   state         - Current state to be solved for time t + dt.
        %   state0        - The converged state at time t.
        %   dt            - The scalar time-step.
        %   forces        - Forces struct. See `getDrivingForces`.
        %
        % OPTIONAL PARAMETERS:
        %   'resOnly'  -  If supported by the equations, this flag will
        %                 result in only the values of the equations being
        %                 computed, omitting any Jacobians.
        %
        %   'iteration' - The nonlinear iteration number. This can be
        %                 provided so that the underlying equations can
        %                 account for the progress of the nonlinear
        %                 solution process in a limited degree, for example
        %                 by updating some quantities only at the first
        %                 iteration.
        %
        % RETURNS:
        %   problem - Instance of the wrapper class `LinearizedProblemAD`
        %             containing the residual equations as well as
        %             other useful information.
        %
        %   state   - The equations are allowed to modify the system
        %             state, allowing a limited caching of expensive
        %             calculations only performed when necessary.
        %
        % SEE ALSO:
        %   `getAdjointEquations`
        %
        error('Base class not meant for direct use')
    end

    function [problem, state] = getAdjointEquations(model, state0, state, dt, forces, varargin)
        % Get the adjoint equations (please read note before use!)
        % 
        % SYNOPSIS:
        %   [problem, state] = model.getAdjointEquations(state0, state, dt, drivingForces)
        %
        % DESCRIPTION:
        %   Function to get equation when using adjoint to calculate
        %   gradients. This make it possible to use different equations to
        %   calculate the solution in the forward mode, for example if
        %   equations are solved explicitly as for hysteretic models.
        %   it is assumed that the solution of the system in forward for the
        %   two different equations are equal i.e `problem.val == 0`.
        %
        % PARAMETERS:
        %   model         - Class instance
        %   state         - Current state to be solved for time t + dt.
        %   state0        - The converged state at time t.
        %   dt            - The scalar time-step.
        %   forces        - Forces struct. See `getDrivingForces`.
        %
        % RETURNS:
        %   problem - `LinearizedProblemAD` derived class containing the
        %              linearized equations used for the adjoint problem.
        %              This function is normally `getEquations` and assumes
        %              that the function supports the `reverseMode`
        %              argument. 
        %   state   -  State. Possibly updated. See `getEquations` for
        %              details.
        %
        % OPTIONAL PARAMETERS:
        %   'reverseMode' - If set to true, the reverse mode of the
        %                   equations are provided.
        %
        % NOTE:
        %   A caveat is that this function provides the forward-mode
        %   version of the adjoint equations, normally identical to
        %   `getEquations`. MRST allows for separate implementations of
        %   adjoint and regular equations in order to allow for rigorous
        %   treatment of hysteresis and other semi-explicit parameters.
        %
        [problem, state] = model.getEquations(state0, state, dt, forces, varargin{:});
    end

    
    function state = validateState(model, state)
        % Validate state and check if it is ready for simulation
        %
        % SYNOPSIS:
        %   state = model.validateState(state);
        %
        % DESCRIPTION:
        %   Validate the state for use with `model`. Should check that
        %   required fields are present and of the right dimensions. If
        %   missing fields can be assigned default values, state is return
        %   with the required fields added. If reasonable default values
        %   cannot be assigned, a descriptive error should be thrown
        %   telling the user what is missing or wrong (and ideally how to
        %   fix it).
        %
        % PARAMETERS:
        %   model  - Class instance for which `state` is intended as a
        %            valid state.
        %   state  - `struct` which is to be validated.
        %
        % RETURNS:
        %   state  - `struct`. If returned, this state is ready for
        %           simulation with `model`. It may have been changed in
        %           the process.
        %   

        % Any state is valid for base class
        return
    end

    
    function model = validateModel(model, varargin)
        % Validate model and check if it is ready for simulation
        %
        % SYNOPSIS:
        %   model = model.validateModel();
        %   model = model.validateModel(forces);
        %
        % DESCRIPTION:
        %   Validate that a model is suitable for simulation. If the
        %   missing or inconsistent parameters can be fixed automatically,
        %   an updated model will be returned. Otherwise, an error should
        %   occur.
        %
        %   Second input may be the forces struct argument. This function
        %   should NOT require forces arg to run, however.
        %
        % PARAMETERS:
        %   model  - Class instance to be validated.
        %   forces - (OPTIONAL): The forces to be used. Some models require
        %            setup and configuration specific to the forces used.
        %            This is especially important for the `FacilityModel`,
        %            which implements the coupling between wells and the
        %            reservoir for `ReservoirModel` subclasses of
        %            `PhysicalModel`.
        % RETURNS:
        %   model - Class instance. If returned, this model is ready for
        %           simulation. It may have been changed in the process.
        %   

        % Base class is always suitable
        return
    end

    
    function [state, report] = updateState(model, state, problem, dx, forces) 
        % Update the state based on increments of the primary values
        %
        % SYNOPSIS:
        %   [state, report] = model.updateState(state, problem, dx, drivingForces)
        %
        % DESCRIPTION:
        %   Update the state's primary variables (and any secondary
        %   quantities computing during the update process) based on a set
        %   of increments to each of the primary variables contained in
        %   `problem.primaryVariables`.
        %
        %   This function should ensure that values are within physically
        %   meaningful values and are meaningful so that the next call to
        %   `stepFunction` can produce yet another set of reasonable
        %   increments in a process that eventually results in convergence.
        %
        % PARAMETERS:
        %   model   -  Class instance
        %   state   - `struct` representing the current state of the solution
        %             variables to be updated.
        %   problem - `LinearizedProblemAD` instance that has
        %             `primaryVariables` which matches `dx` in length and
        %             meaning.
        %   dx      - Cell-wise increments. These are typically output from
        %             `LinearSolverAD.solveLinearizedProblem`.
        %   forces  - The forces used to produce the update. See
        %            `getDrivingForces`.
        %
        % RETURNS:
        %   state  - Updated state with physically reasonable values.
        %   report - Struct with information about the update process.
        %
        % NOTE:
        %   Specific properties can be manually updated with a variety of
        %   different functions. We trust the user and leave these
        %   functions as public. However, the main gateway to the update of
        %   state is through this function to ensure that all values are
        %   updated simultaneously. For many problems, updates can not be
        %   done separately and all changes in the primary variables must
        %   considered together for the optimal performance.
        %   
        for i = 1:numel(problem.primaryVariables)
             p = problem.primaryVariables{i};
             % Update the state
             state = model.updateStateFromIncrement(state, dx, problem, p);
        end
        report = [];
    end

    
    function [model, state] = updateForChangedControls(model, state, forces)
        % Update model and state when controls/drivingForces has changed
        %
        % SYNOPSIS:
        %   [model, state] = model.updateForChangedControls(state, forces)
        %
        % DESCRIPTION:
        %   Whenever controls change, this function should ensure that both
        %   model and state are up to date with the present set of driving
        %   forces.
        %
        % PARAMETERS:
        %   model  - Class instance.
        %   state  - `struct` holding the current solution state.
        %   forces - The new driving forces to be used in subsequent calls
        %            to `getEquations`. See `getDrivingForces`. 
        % RETURNS:
        %   model  - Updated class instance.
        %   state  - Updated `struct` holding the current solution state
        %            with accomodations made for any changed controls that
        %            provide e.g. primary variables.
        %
    end
    
    function [state, report] = updateAfterConvergence(model, state0, state, dt, drivingForces)
        % Final update to the state after convergence has been achieved
        %
        % SYNOPSIS:
        %   [state, report] = model.updateAfterConvergence(state0, state, dt, forces)
        %   
        % DESCRIPTION:
        %   Update state based on nonlinear increment after timestep has
        %   converged. Defaults to doing nothing since not all models
        %   require this.
        %
        %   This function allows for the update of secondary variables
        %   instate after convergence has been achieved. This is especially
        %   useful for hysteretic parameters, where future function
        %   evaluations depend on the previous maximum value over all
        %   converged states.
        %
        % PARAMETERS:
        %   model  - Class instance.
        %   state  - `struct` holding the current solution state.
        %   forces - Driving forces used to execute the step. See
        %            `getDrivingForces`.
        %
        % RETURNS:
        %   state  - Updated `struct` holding the current solution state.
        %   report - Report containing information about the update.
        %
        % EXAMPLE:
        %   
        report = [];
    end

    
    function [convergence, values, names] = checkConvergence(model, problem, n)
        % Check and report convergence based on residual tolerances
        % 
        % SYNOPSIS:
        %   [convergence, values, names] = model.checkConvergence(problem)
        %
        % DESCRIPTION:
        %   Basic convergence testing for a linearized problem. By default,
        %   this simply takes the inf norm of all model equations.
        %   Subclasses are free to overload this function for more
        %   sophisticated and robust options.
        %
        % PARAMETERS:
        %   model   - Class instance
        %   problem - `LinearizedProblemAD` to be checked for convergence.
        %             The default behavior is to check all equations
        %             against `model.nonlinearTolerance` in the inf/max
        %             norm.
        %   n       - OPTIONAL· The norm to be used. Default: `inf`.
        %
        % RETURNS:
        %   convergence - Vector of length `N` with bools indicating
        %                 `true/false` if that residual/error measure has
        %                 converged.
        %   values      - Vector of length `N` containing the numerical
        %                 values checked for convergence.
        %   names       - Cell array of length `N` containing the names
        %                 tested for convergence.
        %
        % NOTE:
        %   By default, `N` is equal to the number of equations in
        %   `problem` and the convergence simply checks the convergence of
        %   each equation against a generic `nonlinearTolerance`.
        %   However, subclasses are free to produce any number of convergence
        %   criterions and they need not correspond to specific equations
        %   at all.
        %   
        if nargin == 2
            n = inf;
        end

        values = norm(problem, n);
        convergence = values < model.nonlinearTolerance;
        names = strcat(problem.equationNames, ' (', problem.types, ')');
    end

    
    function [state, report] = stepFunction(model, state, state0, dt, drivingForces, linsolver, nonlinsolver, iteration, varargin)
        % Perform a step that ideally brings the state closer to convergence
        %
        % SYNOPSIS:
        %   [state, report] = model.stepFunction(state, state0, dt, ...
        %                                        forces, ls, nls, it)
        %
        % DESCRIPTION:
        %   Perform a single nonlinear step and report the progress towards
        %   convergence. The exact semantics of a nonlinear step varies
        %   from model to model, but the default behavior is to linearize
        %   the equations and solve a single step of the Newton-Rapshon
        %   algorithm for general nonlinear equations.

        %
        % PARAMETERS:
        %   model         - Class instance
        %   state         - Current state to be solved for time t + dt.
        %   state0        - The converged state at time t.
        %   dt            - The scalar time-step.
        %   drivingForces - Forces struct. See `getDrivingForces`.
        %   linsolver     - `LinearSolverAD` instance used to solve the
        %                   linear systems that may appear from
        %                   linearization.
        %   nonlinsolver  - `NonLinearSolverAD` controlling the solution
        %                   process.
        %   iteration     - The current nonlinear iterations number. Some
        %                   models implement special logic depending on the
        %                   iteration (typically doing setup during the
        %                   first iteration only).
        %
        % OPTIONAL PARAMETERS:
        %   varargin - Any additional arguments are passed onto
        %              `getEquations` without modification or validation.
        %
        % RETURNS:
        %   state  - Updated state `struct` that hopefully is closer to
        %            convergence in some sense.
        %   report - A report produced by `makeStepReport` which indicates
        %            the convergence status, residual values and other
        %            useful information from the application of the
        %            `stepFunction` as well as any dispatched calls to
        %            other functions.
        %
        % SEE ALSO:
        %   `NonLinearSolverAD`, `LinearSolverAD`, `simulateScheduleAD`
        %
        onlyCheckConvergence = iteration > nonlinsolver.maxIterations;

        [problem, state] = model.getEquations(state0, state, dt, drivingForces, ...
                                   'ResOnly', onlyCheckConvergence, ...
                                   'iteration', iteration, ...
                                   varargin{:});
        problem.iterationNo = iteration;
        problem.drivingForces = drivingForces;
        
        [convergence, values, resnames] = model.checkConvergence(problem);
        
        % Minimum number of iterations can be prescribed, i.e., we
        % always want at least one set of updates regardless of
        % convergence criterion.
        doneMinIts = iteration > nonlinsolver.minIterations;

        % Defaults
        failureMsg = '';
        failure = false;
        [linearReport, updateReport, stabilizeReport] = deal(struct());
        if (~(all(convergence) && doneMinIts) && ~onlyCheckConvergence)
            % Get increments for Newton solver
            [dx, ~, linearReport] = linsolver.solveLinearProblem(problem, model);
            if any(cellfun(@(d) ~all(isfinite(d)), dx))
                failure = true;
                failureMsg = 'Linear solver produced non-finite values.';
            end
            % Let the nonlinear solver decide what to do with the
            % increments to get the best convergence
            [dx, stabilizeReport] = nonlinsolver.stabilizeNewtonIncrements(model, problem, dx);

            if (nonlinsolver.useLinesearch && nonlinsolver.convergenceIssues) || ...
                nonlinsolver.alwaysUseLinesearch
                [state, updateReport, stabilizeReport.linesearch] = nonlinsolver.applyLinesearch(model, state0, state, problem, dx, drivingForces, varargin{:});
            else
                % Finally update the state. The physical model knows which
                % properties are actually physically reasonable.
                [state, updateReport] = model.updateState(state, problem, dx, drivingForces);
            end
        end
        isConverged = (all(convergence) && doneMinIts) || model.stepFunctionIsLinear;
        
        % If step function is linear, we need to call a residual-only
        % equation assembly to ensure that indirect/derived quantities are
        % set with the updated values (fluxes, mobilities and so on).
        if model.stepFunctionIsLinear
            [~, state] = model.getEquations(state0, state, dt, drivingForces, ...
                                   'ResOnly', true, ...
                                   'iteration', iteration+1, ...
                                   varargin{:});
        end
        if model.verbose
            printConvergenceReport(resnames, values, convergence, iteration);
        end
        report = model.makeStepReport(...
                        'LinearSolver', linearReport, ...
                        'UpdateState',  updateReport, ...
                        'Failure',      failure, ...
                        'FailureMsg',   failureMsg, ...
                        'Converged',    isConverged, ...
                        'Residuals',    values, ...
                        'StabilizeReport', stabilizeReport,...
                        'ResidualsConverged', convergence);
    end

    
    function report = makeStepReport(model, varargin)
        % Get the standardized report all models provide from `stepFunction`
        %
        % SYNOPSIS:
        %   report = model.makeStepReport('Converged', true);
        %
        % DESCRIPTION:
        %   Normalized struct with a number of useful fields. The most
        %   important fields are the fields representing `Failure` and
        %   `Converged` which `NonLinearSolver` reacts appropriately to.
        %
        % PARAMETERS:
        %   model - Class instance
        %
        % OPTIONAL PARAMETERS:
        %   various - Keyword/value pairs that override the default values.
        %
        % RETURNS:
        %   report - Normalized report with defaulted values where not
        %            provided.
        %
        % SEE ALSO:
        %   `stepFunction`, `NonLinearSolverAD`
        report = struct('LinearSolver', [], ...
                        'UpdateState',  [], ...
                        'Failure',      false, ...
                        'FailureMsg',   '', ...
                        'Converged',    false, ...
                        'FinalUpdate',  [],...
                        'Residuals',    [],...
                        'StabilizeReport', [], ...
                        'ResidualsConverged', []);
        report = merge_options(report, varargin{:});
    end

    
    function [gradient, result, report] = solveAdjoint(model, solver, getState,...
                                getObj, schedule, gradient, stepNo)
        % Solve a single linear adjoint step to obtain the gradient
        %
        % SYNOPSIS:
        %   gradient = model.solveAdjoint(solver, getState, ...
        %                           getObjective, schedule, gradient, itNo)  
        %
        % DESCRIPTION:
        %  This solves the linear adjoint equations. This is the backwards
        %  analogue of the forward mode `stepFunction` in `PhysicalModel`
        %  as well as the `solveTimestep` method in `NonLinearSolver`.
        %
        % PARAMETERS:
        %   model    - Class instance.
        %   solver   - Linear solver to be used to solve the linearized
        %              system.
        %   getState - Function handle. Should support the syntax::
        %
        %                state = getState(stepNo)
        %
        %              To obtain the converged state from the forward
        %              simulation for step `stepNo`.
        %   getObj   - Function handle providing the objective function for
        %              a specific step `stepNo`::
        %
        %                objfn = getObj(stepNo)
        %
        %   schedule - Schedule used to compute the forward simulation.
        %   gradient - Current gradient to be updated. See outputs.
        %   stepNo   - The current control step to be solved.
        %
        % RETURNS:
        %   gradient - The updated gradient.
        %   result   - Solution of the adjoint problem.
        %   report   - Report with information about the solution process.
        %
        % SEE ALSO:
        %   `computeGradientAdjointAD`
        %   
        validforces = model.getValidDrivingForces();
        dt_steps = schedule.step.val;

        current = getState(stepNo);
        before    = getState(stepNo - 1);        
        dt = dt_steps(stepNo);

        lookupCtrl = @(step) schedule.control(schedule.step.control(step));
        % get forces and merge with valid forces
        forces = model.getDrivingForces(lookupCtrl(stepNo));
        forces = merge_options(validforces, forces{:});
        model = model.validateModel(forces);
        
        % Initial state typically lacks wellSol-field, so add if needed
        if stepNo == 1
            before = model.validateState(before);
        end
        
        % We get the forward equations via the reverseMode flag. This is
        % slightly hacky (we should use the forward equations instead), but
        % we assume that the reverseMode flag takes care of this for us.
        % This slightly messy setup is made to support hysteresis models,
        % where the forward and backwards equations are very different.
        problem = model.getAdjointEquations(before, current, dt, forces, ...
                                    'reverseMode', false, 'iteration', inf);

        if stepNo < numel(dt_steps)
            after    = getState(stepNo + 1);
            dt_next = dt_steps(stepNo + 1);
            % get forces and merge with valid forces
            forces_p = model.getDrivingForces(lookupCtrl(stepNo + 1));
            forces_p = merge_options(validforces, forces_p{:});
            problem_p = model.getAdjointEquations(current, after, dt_next, forces_p,...
                                'iteration', inf, 'reverseMode', true);
        else
            problem_p = [];
        end
        [gradient, result, rep] = solver.solveAdjointProblem(problem_p,...
                                    problem, gradient, getObj(stepNo), model);
        report = struct();
        report.Types = problem.types;
        report.LinearSolverReport = rep;
    end

    
    function [fn, index] = getVariableField(model, name, throwError)
        % Map known variable by name to field and column index in `state`
        %
        % SYNOPSIS:
        %   [fn, index] = model.getVariableField('someKnownField')
        %
        % DESCRIPTION:
        %   Get the index/name mapping for the model (such as where
        %   pressure or water saturation is located in state). For this
        %   parent class, this always result in an error, as this model 
        %   knows of no variables.
        %
        %   For subclasses, however, this function is the primary method
        %   the class uses to map named values (such as the name of a
        %   component, or the human readable name of some property) and the
        %   compact representation in the state itself.
        %
        % PARAMETERS:
        %   model - Class instance.
        %   name  - The name of the property for which the storage field in
        %           `state` is requested. Attempts at retrieving a field
        %           the model does not know results in an error.
        %   throwError - OPTIONAL: If set to false, no error is thrown and
        %                empty fields are returned.
        % RETURNS:
        %   fn    - Field name in the `struct` where `name` is stored.
        %   index - Column index of the data.
        %
        % SEE ALSO:
        %   `getProp`, `setProp`
        %   
        [fn, index] = deal([]);

        if nargin < 3
            throwError = true;
        end
        if isempty(index) && throwError
            error('PhysicalModel:UnknownVariable', ...
                ['State variable ''', name, ''' is not known to this model']);
        end
    end

    
    function p = getProp(model, state, name)
        % Get a single property from the nonlinear state
        %
        % SYNOPSIS:
        %   p = model.getProp(state, 'pressure');
        %
        % PARAMETERS:
        %   model - Class instance.
        %   state - `struct` holding the state of the nonlinear problem.
        %   name  - A property name supported by the model's
        %           `getVariableField` mapping.
        %
        % RETURNS:
        %   p     - Property taken from the state.
        %
        % SEE ALSO:
        %   `getProps`
        
        [fn, index] = model.getVariableField(name);
        p = state.(fn)(:, index);
    end

    
    function varargout = getProps(model, state, varargin)
        % Get multiple properties from state in one go
        %
        % SYNOPSIS:
        %   [p, s] = model.getProps(state, 'pressure', 's');
        %
        % PARAMETERS:
        %   model - Class instance.
        %   state - `struct` holding the state of the nonlinear problem.
        %
        % OPTIONAL PARAMETERS:
        %   'FieldName' - Property names to be extracted. Any number of
        %                 properties can be requested.
        %
        % RETURNS:
        %   varargout - Equal number of output arguments to the number of
        %               property strings sent in, corresponding to the
        %               respective properties.
        %
        % SEE ALSO:
        %   `getProp`
        varargout = cellfun(@(x) model.getProp(state, x), ...
                            varargin, 'UniformOutput', false);
    end

    
    function state = incrementProp(model, state, name, increment)
        % Increment named state property by given value
        %
        % SYNOPSIS:
        %   state = model.incrementProp(state, 'PropertyName', increment)
        %
        % PARAMETERS:
        %   model - Class instance.
        %   state - `struct` holding the state of the nonlinear problem.
        %   name  - Name of the property to updated. See `getVariableField`
        %   value - The increment that will be added to the current value
        %           of property `name`.
        %
        % RETURNS:
        %   state - Updated state `struct`.
        %
        % EXAMPLE:
        %   % For a model which knows of the field 'pressure', increment
        %   % the value by 7 so that the final value is 10 (=3+7).
        %   state = struct(‘pressure’, 3); 
        %   state = model.incrementProp(state, ‘pressure’, 7);

        
        [fn, index] = model.getVariableField(name);
        p = state.(fn)(:, index)  + increment;
        state.(fn)(:, index) = p;
    end

    
    function state = setProp(model, state, name, value)
        % Set named state property to given value
        %
        % SYNOPSIS:
        %   state = model.setProp(state, 'PropertyName', value)
        %
        % PARAMETERS:
        %   model - Class instance.
        %   state - `struct` holding the state of the nonlinear problem.
        %   name  - Name of the property to updated. See `getVariableField`
        %   value - The updated value that will be set.
        %
        % RETURNS:
        %   state - Updated state `struct`.
        %
        % EXAMPLE:
        %   % This will set state.pressure to 5 if the model knows of a
        %   % state field named pressure. If it is not known, it will
        %   % result in an error.
        %   state = struct('pressure', 0);
        %   state = model.setProp(state, 'pressure', 5);
        
        [fn, index] = model.getVariableField(name);
        state.(fn)(:, index) = value;
    end

    
    function dv = getIncrement(model, dx, problem, name)
        % Get specific named increment from a list of different increments.
        %
        % SYNOPSIS:
        %   dv = model.getIncrement(dx, problem, 'name')
        %
        % DESCRIPTION:
        %   Find increment in linearized problem with given name, or
        %   output zero if not found. A linearized problem can give
        %   updates to multiple variables and this makes it easier to get
        %   those values without having to know the order they were input
        %   into the constructor.
        %
        % PARAMETERS:
        %   model   - Class instance.
        %   dx      - Cell array of increments corresponding to the names
        %             in `problem.primaryVariables`.
        %   problem - Instance of `LinearizedProblem` from which the
        %             increments were computed.
        %   name    - Name of the variable for which the increment is to be
        %             extracted. 
        %
        % RETURNS:
        %   dv      - The value of the increment, if it is found. Otherwise
        %             a scalar zero value is returned.

        isVar = problem.indexOfPrimaryVariable(name);
        if any(isVar)
            dv = dx{isVar};
        else
            dv = 0;
        end
    end

    
    function [state, val, val0] = updateStateFromIncrement(model, state, dx, problem, name, relchangemax, abschangemax)
        % Update value in state, with optional limits on update magnitude
        %
        % SYNOPSIS:
        %   state = model.updateStateFromIncrement(state, dx, problem, 'name')
        %   [state, val, val0] = model.updateStateFromIncrement(state, dx, problem, 'name', 1, 0.1)
        %
        % PARAMETERS:
        %   model   - Class instance.
        %   state   - State `struct`to be updated.
        %   dx      - Increments. Either a `cell` array matching the the
        %             primary variables of `problem`, or a single value.
        %   problem - `LinearizedProblem` used to obtain the increments.
        %             This input argument is only used if `dx` is a
        %             `cell` array and can be replaced by a dummy value if
        %             `dx` is a numerical type.
        %   name    - Name of the field to update, as supported by
        %             `model.getVariableField`.
        %   relchangemax - OPTIONAL. If provided, this will be interpreted
        %                  as the maximum *relative* change in the variable
        %                  allowed.
        %   abschangemax - OPTIONAL. If provided, this is the maximum
        %                  *absolute* change in the variable allowed.
        %
        % RETURNS:
        %   state - State with updated value.
        %
        % EXAMPLE:
        %   % Update pressure with an increment of 10, without any limits,
        %   % resulting in the pressure being 110 after the update.
        %   state = struct('pressure', 10);
        %   state = model.updateStateFromIncrement(state, 100, problem, 'pressure')
        %   % Alternatively, we can use a relative limit on the update. In
        %   % the following, the pressure will be set to 11 as an immediate
        %   % update to 110 would violate the maximum relative change of
        %   % 0.1 (10 %)
        %    state = model.updateStateFromIncrement(state, 100, problem, 'pressure', .1)
        %
        % NOTE:
        %   Relative limits such as these are important when working with
        %   tabulated and nonsmooth properties in a Newton-type loop, as the
        %   initial updates may be far outside the reasonable region of
        %   linearization for a complex problem. On the other hand, limiting
        %   the relative updates can delay convergence for smooth problems
        %   with analytic properties and will, in particular, prevent zero
        %   states from being updated, so use with care.
        
        if iscell(dx)
            % We have cell array of increments, use the problem to
            % determine where we can actually find it.
            dv = model.getIncrement(dx, problem, name);
        else
            % Numerical value, increment directly and do not safety
            % check that this is a part of the model
            dv = dx;
        end

        val0 = model.getProp(state, name);

        [changeRel, changeAbs] = deal(1);
        if nargin > 5
            [~, changeRel] = model.limitUpdateRelative(dv, val0, relchangemax);
        end
        if nargin > 6
            [~, changeAbs] = model.limitUpdateAbsolute(dv, abschangemax);
        end            
        % Limit update by lowest of the relative and absolute limits 
        change = min(changeAbs, changeRel);

        val   = val0 + dv.*repmat(change, 1, size(dv, 2));
        state = model.setProp(state, name, val);
    end
    
    function state = capProperty(model, state, name, minvalue, maxvalue)
        % Ensure that a property is within a specific range by capping.
        %
        % SYNOPSIS:
        %   state = model.capProperty(state, 'someProp', minValOfProp)
        %   state = model.capProperty(state, 'someProp', minValOfProp, maxValOfProp)
        %
        % PARAMETERS:
        %   model    - Class instance.
        %   state    - State `struct`to be updated.
        %   name     - Name of the field to update, as supported by
        %              `model.getVariableField`.
        %   minvalue - Minimum value of state property `name`. Any values
        %              below this threshold will be set to this value. Set
        %              to `-inf` for no lower bound.
        %   maxvalue - OPTIONAL: Maximum value of state property `name`.
        %              Values that are larger than this limit are set to
        %              the limit. For no upper limit, set `inf`.
        %
        % RETURNS:
        %   state - State `struct` where `name` is within the limits.
        %
        % EXAMPLE:
        %   % Make a random field, and limit it to the range [0.2, 0.5].
        %   state = struct('pressure', rand(10, 1))
        %   state = model.capProperty(state, 0.2, 0.5);
        %   disp(model.getProp(state, 'pressure'))
        %
        v = model.getProp(state, name);
        v = max(minvalue, v);
        if nargin > 4
            v = min(v, maxvalue);
        end
        state = model.setProp(state, name, v);
    end
    
    
    function [vararg, control] = getDrivingForces(model, control)
        % Get driving forces in expanded format.
        %
        % SYNOPSIS:
        %   vararg = model.getDrivingForces(schedule.control(ix))
        %
        % PARAMETERS:
        %   model   - Class instance
        %   control - Struct with the driving forces as fields. This should
        %             be a struct with the same fields as in
        %             `getValidDrivingForces`, although this is not
        %             explicitly enforced in this routine.
        %
        % RETURNS:
        %   vararg - Cell-array of forces in the format::
        %
        %              {'W', W, 'bc', bc, ...}
        %
        %            This is typically used as input to variable input
        %            argument functions that support various boundary
        %            conditions options.
        %
        vrg = [fieldnames(control), struct2cell(control)];
        vararg = reshape(vrg', 1, []);
    end
    
    
    function forces = getValidDrivingForces(model)
        % Get a struct with the default valid driving forces for the model
        %
        % SYNOPSIS:
        %   forces = model.getValidDrivingForces();
        %
        % DESCRIPTION:
        %   Different models support different types of boundary
        %   conditions. Each model should implement a default struct,
        %   showing the solvers what a typical allowed struct of boundary
        %   conditions looks like in terms of the named fields present.
        %
        % PARAMETERS:
        %   model  - Class instance
        %
        % RETURNS:
        %   forces - A struct with any number of fields. The fields must be
        %            present, but they can be empty.
        %
        forces = struct();
    end
    
    
    function checkProperty(model, state, property, n_el, dim)
        % Check dimensions of property and throw error if dims do not match
        %
        % SYNOPSIS:
        %   model.checkProperty(state, 'pressure', G.cells.num, 1);
        %   model.checkProperty(state, 'components', [ncell, ncomp], [1, 2]);
        %
        %
        % PARAMETERS:
        %   model    - Class instance.
        %   state    - State `struct`to be checked.
        %   name     - Name of the field to check, as supported by
        %              `model.getVariableField`.
        %   n_el     - Array of length `N` where entry `i`corresponds to
        %              the size of the property in dimension `dim(i)`.
        %   dim      - Array of length `N` corresponding to the dimensions
        %              for which `n_el` is to be checked.
        %
        if numel(dim) > 1
            assert(numel(n_el) == numel(dim));
            % Recursively check all dimensions 
            for i = 1:numel(dim)
                model.checkProperty(state, property, n_el(i), dim(i));
            end
            return
        end
        fn = model.getVariableField(property);
        assert(isfield(state, fn), ['Field ".', fn, '" missing! ', ...
            property, ' must be supplied for model "', class(model), '"']);

        if dim == 1
            sn = 'rows';
        elseif dim == 2
            sn = 'columns';
        else
            sn = ['dimension ', num2str(dim)];
        end
        n_actual = size(state.(fn), dim);
        assert(n_actual == n_el, ...
            ['Dimension mismatch for ', sn, ' of property "', property, ...
            '" (state.', fn, '): Expected ', sn, ' to have ', num2str(n_el), ...
            ' entries but state had ', num2str(n_actual), ' instead.'])
    end
end

methods (Static)
    
    function [dv, change] = limitUpdateRelative(dv, val, maxRelCh)
        % Limit a update by relative limit
        biggestChange = max(abs(dv./val), [], 2);
        change = min(maxRelCh./biggestChange, 1);
        dv = dv.*repmat(change, 1, size(dv, 2));
    end
    
    function [dv, change] = limitUpdateAbsolute(dv, maxAbsCh)
        % Limit a update by absolute limit
        biggestChange = max(abs(dv), [], 2);
        change = min(maxAbsCh./biggestChange, 1);
        dv = dv.*repmat(change, 1, size(dv, 2));
    end
    
    function [vars, isRemoved] = stripVars(vars, names)
        isRemoved = cellfun(@(x) any(strcmpi(names, x)), vars);
        vars(isRemoved) = [];
    end
end
end

%{
Copyright 2009-2017 SINTEF ICT, Applied Mathematics.

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

