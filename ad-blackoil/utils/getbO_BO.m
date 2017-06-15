function bG = getbO_BO(model, p, rs, isSaturated)
% Utility function for evaluating the reciprocal oil formation volume
% factor function.
    if isprop(model, 'disgas') && model.disgas
        bG = model.fluid.bO(p, rs, isSaturated);
    else
        bG = model.fluid.bO(p);
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
