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
error_locator_roots = gf([],a.m,a.prim_poly); % error-locator polynomial roots
error_locations = gf([],a.m,a.prim_poly); % error locations
symbol_locations = gf([],a.m,a.prim_poly); % error symbol locations
for i=0:2^a.m-2
    x = gf(0,a.m,a.prim_poly);
    for k=length(cx):-1:1
        x = x + cx(k)*(a^i)^(length(cx)-k);
    end
    if x==0
        error_locator_roots = [error_locator_roots a^i];
        error_locations = [error_locations inv(a^i)];
        symbol_locations = [symbol_locations i];
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

% calculate error evaluator polynomial
error_evaluator = gf(zeros(1,lcx),a.m,a.prim_poly);
for i=1:lcx
    tmps = gf(s(lcx+1-i:-1:1),a.m,a.prim_poly);
    tmpc = gf(cx(length(cx):-1:length(cx)-lcx+i),a.m,a.prim_poly);
    tmp = tmps.*tmpc;

    for k=1:length(tmp)
        error_evaluator(length(error_evaluator)+1-i) = error_evaluator(length(error_evaluator)+1-i) + tmp(k);
    end
end

% Forney's algorithm
% evaluate error evaluator at error locator roots

% Calculate numerators
eval_numerators = gf(zeros(size(error_evaluator)),a.m,a.prim_poly);
for i=1:length(er)
    for k=1:length(error_evaluator)
        eval_numerators(i) = eval_numerators(i) + error_evaluator(k)*error_locator_roots(i)^(k-1);
    end
    en = eval_numerators(i);
    fprintf('Numerator %i: %i\n',i,en.x);
end

% Calculate denominators
eval_denominators = gf(zeros(size(error_locator_roots)),a.m,a.prim_poly);
for i=1:length(error_locator_roots)
    eval_denominators(i) = error_locations(i);
    one = gf(1,a.m,a.prim_poly);
    for k=1:length(error_locations)
        if k ~= i
            eval_denominators(i) = eval_denominators(i) * (one + error_locations(k)*error_locator_roots(i));
        end
    end
end

% divide to get error values
ev = gf(zeros(size(el)),a.m,a.prim_poly);
for i=1:length(el)
    ev(i) = eval_numerators(i)*inv(eval_denominators(i));
end

z0evalx = eval_numerator.x;
z0x = z0.x;
eix = ei.x;
erx = er.x;

fprintf(file,'%i ',[erx zeros(1,length(cx)-lcx) z0x]);
fprintf(file,'\n');

fclose(file);

%write do file
file = fopen('../t_forney_calculator.do','w');
fprintf(file,'vsim vhdlib_tb(forney_calculator_tb)\n');
fprintf(file,'log -r /*\n');
fprintf(file,'do t_forney_calculator_wave.do\n');
fprintf(file,'run %i ns\n',300);
fclose(file);
