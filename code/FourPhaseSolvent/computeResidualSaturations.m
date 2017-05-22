function [sWres, sOres, sSGres] = computeResidualSaturations(fluid, p, sG, sS)
    % Calculate effective residual saturations

    % Residual saturations for the immiscible and miscible extrema
    sOres_m    = fluid.sOres_m ;
    sOres_i    = fluid.sOres_i ;
    sSGres_m   = fluid.sSGres_m;
    sSGres_i   = fluid.sSGres_i;
    
    % Misscibility is a function of the solvent fraction in the total gas
    % phase
    M = fluid.Msat(sG, sS).*fluid.Mpres(p);
    
    % Interpolated water/oil residual saturations
    sWres  = fluid.sWres;
    sOres  = M.*sOres_m  + (1 - M).*sOres_i ;
    sSGres = M.*sSGres_m + (1 - M).*sSGres_i;
    
end