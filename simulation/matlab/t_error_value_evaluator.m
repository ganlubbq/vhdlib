clc;

file = fopen('../t_error_value_evaluator.txt','w');

%alpha
t = 3;
gf_poly = 19;
m = floor(log2(gf_poly));
a = gf(2,m,gf_poly); %alpha

%received vector
r = gf([0 0 0 a^7 0 0 a^3 0 0 0 0 0 a^4 0 0],m,gf_poly);
% r = gf([0 0 0 0 0 0 a^3 0 0 0 0 0 a^4 0 0],m,gf_poly);
% calculate syndromes using Horner scheme
r = r(length(r):-1:1); % reverse
rx = r.x;

aa = a.^(1:2*t); 
sa = gf(zeros(1,2*t),m,gf_poly);

for i=1:length(r)
    for k=1:length(sa)
        sa(k) = sa(k)*aa(k) + r(i);
    end
end
fprintf(file,'%i ',sa.x); % syndromes

% Berlekamp-Massey algorithm
cx = gf([zeros(1,2*t-1) 1],a.m,a.prim_poly);
bx = gf([zeros(1,2*t-1) 1],a.m,a.prim_poly);
L = 0;
m = 1;
d = gf(0,a.m,a.prim_poly);
b = gf(1,a.m,a.prim_poly);

for n=0:2*t-1
    
    %discrepancy
    d = sa(n+1);

    sax = sa.x;
    cxx = cx.x;
    for k=1:L
        d = d + sa(n+1-k)*cx(length(cx)-k);
    end

    binv = inv(b);
    if d==0
        m = m + 1;
    elseif 2*L <= n
        tmp = cx;
        cx = cx - (d*inv(b) * gf([ bx(1+m:length(bx)) zeros(1,m)],a.m,a.prim_poly));
        
        L = n + 1 - L;
        bx = tmp;
        b = d;
        m = 1;
    else
        cx = cx - (d*inv(b) * gf([ bx(1+m:length(bx)) zeros(1,m)],a.m,a.prim_poly));
        m = m + 1;
    end
end

fprintf(file,'%i ',cx.x); % Error locator

% degree of error-locator polynomial
lcx = length(cx); 
for i=1:length(cx)
    lcx = lcx-1;
    if cx(i) ~= 0
        break
    end
end

z0 = gf(zeros(1,2*t),a.m,a.prim_poly);
for i=1:length(z0)
    tmps = gf(sa(1:length(z0)+1-i),a.m,a.prim_poly);  
    tmpc = gf(cx(i:length(cx)),a.m,a.prim_poly);
    tmp = tmps.*tmpc;    
    for k=1:length(tmp)
%         z0(length(z0)+1-i) = z0(length(z0)+1-i) + tmp(k);
        z0(i) = z0(i) + tmp(k);
    end
end

z0x = z0.x;
fprintf(file,'%i ',z0x); % Error-value evaluator
fprintf(file,'\n');

fclose(file);

%write do file
file = fopen('../t_error_value_evaluator.do','w');
fprintf(file,'vsim vhdlib_tb(error_value_evaluator_tb)\n');
fprintf(file,'log -r /*\n');
fprintf(file,'do t_error_value_evaluator_wave.do\n');
fprintf(file,'run %i ns\n',300);
fclose(file);