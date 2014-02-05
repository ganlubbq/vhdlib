function bin2hex( bv )
%prints binary vector as hexadecimal
    if mod(length(bv),4) ~= 0
        bv = [zeros(1,4-mod(length(bv),4)) bv];
    end
    for i=1:4:length(bv)
        x = bv(i)*8 + bv(i+1)*4 + bv(i+2)*2 + bv(i+3);
        fprintf('%X',x);
    end
    fprintf('\n');
end

