function [krW, krO, krG] = computeThreePhaseRelPermSft(sW, sO, sG, c, Nc, fluid)
%
%
% SYNOPSIS:
%   function [krW, krO, krG] = computeThreePhaseRelPermSft(sW, sO, sG, c, Nc, fluid)
%
% DESCRIPTION: Computes three-phase water-oil-gas relative permeabilities, using the
% surfactant model as described in  ad-eor/docs/surtactant_model.pdf
%
% PARAMETERS:
%   sW    - Water saturation
%   sO    - Oil saturation
%   sG    - Gas saturation
%   c     - Concentration
%   Nc    - Capillary number
%   fluid - Fluid structure
%
% RETURNS:
%   krW - Water relative permeability
%   krO - Oil relative permeability
%   krG - Gas relative permeability
%
% EXAMPLE:
%
% SEE ALSO: `computeRelPermSft`, `relPermWOG`
%

%{
Copyright 2009-2018 SINTEF Digital, Mathematics & Cybernetics.

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

%         sWcon = 0;
%         if isfield(f, 'sWcon')
%             if isempty(varargin) || numel(f.sWcon) == 1
%                 sWcon = f.sWcon;
%             else
%                 assert(strcmp(varargin{1}, 'cellInx'))
%                 sWcon = f.sWcon(varargin{2});
%             end
%         end
%         sWcon = min(sWcon, double(sw)-1e-5);
        
%         d  = (sg+sw-swcon);
%         ww = (sw-swcon)./d;
%% 求Nc、m 不需要改动   
    isSft = (double(c) > 0);
    m = 0*c;
    if nnz(isSft) > 0
       logNc = log(Nc(isSft))/log(10);
       % We cap logNc (as done in Eclipse)
       logNc = min(max(-20, logNc), 20);
       m(isSft) = fluid.miscfact(logNc, 'cellInx', find(isSft));
    end

%% 求饱和度横坐标端点，需要加上与swcon对应的sorw，而sgr与sorg不需要改动。
%  此外，需要调出assign中表活剂计算相渗的文件，看明白代码，修改sorw，加上krog和krg。
%  此处可能会需要用到data文件中的东西，进一步需要看TD。
    
    sWcon    = fluid.sWcon;    % Residual water saturation   without surfactant
    sOres    = fluid.sOres;    % Residual oil saturation     without surfactant
    sWconSft = fluid.sWconSft; % Residual water saturation   with    surfactant
    sOresSft = fluid.sOresSft; % Residual oil saturation     with    surfactant

    % Interpolated water/oil residual saturations
    sNcWcon = m.*sWconSft + (1 - m).*sWcon;
    sNcOres = m.*sOresSft + (1 - m).*sOres;

    sNcEff = (sW - sNcWcon)./(1 - sNcWcon - sNcOres);

 %% 求表活剂条件下krW和krOW
    
    % Rescaling of the saturation - without surfactant
    sNcWnoSft = (1 - sWcon - sOres).*sNcEff + sWcon;
    krNcWnoSft = fluid.krW(sNcWnoSft);
    krNcOnoSft = fluid.krOW(1 - sNcWnoSft);

 %% 求无表活剂条件下krW和krOW
    
    % Rescaling of the saturation - with surfactant
    sNcWSft =  (1 - sWconSft - sOresSft).*sNcEff + sWconSft;
    krNcWSft = fluid.krW(sNcWSft);
    krNcOSft = fluid.krOW(1 - sNcWSft);

 %% 求kr，加上krg和krog（这两个值维持原黑油模型不变），kro计算需要ww和wg。
    
    krW = m.*krNcWSft + (1 - m).*krNcWnoSft;
    krO = m.*krNcOSft + (1 - m).*krNcOnoSft;
    krG = fluid.krG(sG)


end
