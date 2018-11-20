function f = assignSGOF(f, sgof, reg)
   cfun  = @(f) cellfun(f, sgof, 'UniformOutput', false);

   % Compute tables (static data)
   Tkrg  = extendTab( cfun(@(x) x(:, [1, 2])) );
   Tkro  = extendTab( cfun(@(x) x(:, [1, 3])) );
   Tpcog = extendTab( cfun(@(x) x(:, [1, 4])) );

   % Region mapping
   regmap = @(sw, varargin) ...
      getRegMap(sw, reg.SATNUM, reg.SATINX, varargin{:});

   if isfield(f, 'sWcon')
       if numel(f.sWcon) == 1
           sgas = @(so, varargin) 1 - so - f.sWcon;
       else
           sgas = @(so, varargin) 1 - so - selectSubset(f.sWcon, varargin{:});
       end
   else
       sgas = @(so) 1 - so;
   end

   % Region interpolator
   ireg = @(T, sg, varargin) interpReg(T, sg, regmap(sg, varargin{:}));

   f.krG  = @(sg, varargin) ireg(Tkrg , sg                   , varargin{:});
   f.krOG = @(so, varargin) ireg(Tkro , sgas(so, varargin{:}), varargin{:});
   f.pcOG = @(sg, varargin) ireg(Tpcog, sg                   , varargin{:});
end

function v = selectSubset(v, varargin)
if ~isempty(varargin)
    subset = varargin{2};
    v = v(subset);
end
end
%{
Copyright 2009-2018 SINTEF ICT, Applied Mathematics.

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
