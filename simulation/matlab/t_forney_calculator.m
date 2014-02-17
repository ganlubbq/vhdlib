clc;

file = fopen('../t_forney_calculator.txt','w');

t = 3;

%alpha
a = gf(2,4);

%received vector
r = gf([0 0 0 a^7 0 0 a^3 0 0 0 0 0 a^4 0 0],a.m,a.prim_poly);
% r = gf([0 0 0 0 0 0 a^3 0 0 0 0 0 a^4 0 0],a.m,a.prim_poly);

%calculate syndromes
s = gf(zeros(1,2*t),a.m,a.prim_poly);
for i=1:length(s)
    for k=1:length(r)
        s(i) = s(i) + r(k)*(a^i)^(k-1);
    end
end

% Berlekamp-Massey algorithm
cx = gf([zeros(1,2*t-1) 1],a.m,a.prim_poly);
bx = gf([zeros(1,2*t-1) 1],a.m,a.prim_poly);
L = 0;
m = 1;
d = gf(0,a.m,a.prim_poly);
b = gf(1,a.m,a.prim_poly);

for n=0:2*t-1
    
    %discrepancy
    d = s(n+1);
    for k=1:L
        d = d + s(n+1-k)*cx(length(cx)-k);
    end

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

% find error locations (Chien search)
er = gf([],a.m,a.prim_poly); % error-locator polynomial roots
el = gf([],a.m,a.prim_poly); % error locations
ei = gf([],a.m,a.prim_poly); % error symbol locations
for i=0:2^a.m-2
    x = gf(0,a.m,a.prim_poly);
    ai = a^i;
    for k=length(cx):-1:1
        x = x + cx(k)*ai^(length(cx)-k);
    end
    if x==0
        ei = [ei i];
        er = [er a^i];
        el = [el inv(a^i)];
    end
end

% degree of error-locator polynomial
lcx = length(cx); 
for i=1:length(cx)
    lcx = lcx-1;
    if cx(i) ~= 0
        break
    end
end

% find error-value evaluator
z0 = gf(zeros(1,lcx),a.m,a.prim_poly);
for i=1:lcx
    tmps = gf(s(lcx+1-i:-1:1),a.m,a.prim_poly);
 
    tmpc = gf(cx(length(cx):-1:length(cx)-lcx+i),a.m,a.prim_poly);

    tmp = tmps.*tmpc;

    for k=1:length(tmp)
        z0(length(z0)+1-i) = z0(length(z0)+1-i) + tmp(k);
    end
end

% Forney's algorithm

% evaluate Z_0 at error-locator roots (numerator)
z0eval = gf(zeros(size(z0)),a.m,a.prim_poly);
for i=1:length(er)
    ex = er(i);
    eix = ei(i);
    for k=1:length(z0)
        zx = z0(k);
        z0eval(i) = z0eval(i) + er(i)^(k-1)*z0(k);
    end
    zex = z0eval(i);
end

% denominator
cxdeval = gf(zeros(size(er)),a.m,a.prim_poly);
for i=1:length(er)
    cxdeval(i) = el(i);
    for k=1:length(el)
        if k ~= i
            cxdeval(i) = cxdeval(i) * (gf(1,a.m,a.prim_poly) + el(k)*er(i));
        end
    end
end

% divide to get error values
ev = gf(zeros(size(el)),a.m,a.prim_poly);
for i=1:length(el)
    ev(i) = z0eval(i)*inv(cxdeval(i));
end

z0evalx = z0eval.x;
z0x = z0.x;
eix = ei.x;

fprintf(file,'%i ',[eix zeros(1,length(cx)-lcx) z0x]);
fprintf(file,'\n');

fclose(file);

%write do file
file = fopen('../t_forney_calculator.do','w');
fprintf(file,'vsim vhdlib_tb(forney_calculator_tb)\n');
fprintf(file,'log -r /*\n');
fprintf(file,'do t_forney_calculator_wave.do\n');
fprintf(file,'run %i ns\n',300);
fclose(file);