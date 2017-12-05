function [fx, cx] = splitFaceCellValue(operators, flag, x, sz)
% Evaluate multi-valued function into cell and face values
    nf = sz(1);
    nc = sz(2);
    
    if isa(x, 'ADI')
        n = numval(x);
    else
        n = numel(x);
    end
    
    switch n
        case nc
            % Cell-wise values only, use upstream weighting
            fx = operators.faceUpstr(flag, x);
            cx = x;
        case nf + nc
            % Face values first, then cell values
            fx = x(1:nf);
            cx = x((nf+1):end);
        case 2*nf + nc
            % Half face values
            subs = (1:nf)' + ~flag.*nf;
            fx = x(subs);
            cx = x((2*nf+1):end);
        case nf
            fx = x(1:nf);
            error('Not implemented yet');
        case 2*nf
            error('Not implemented yet');
        otherwise
            error('Did not find expected dimension of input');
    end
end