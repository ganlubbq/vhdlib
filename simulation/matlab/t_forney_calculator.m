clc;

file = fopen('../t_forney_calculator.txt','w');

t = 3;

%alpha
a = gf(2,4);

%received vector
%r = gf([0 0 0 a^7 0 0 a^3 0 0 0 0 0 a^4 0 0],a.m,a.prim_poly);
%r = gf([0 0 0 0 0 0 a^3 0 0 0 0 0 a^4 0 0],a.m,a.prim_poly);
%r = gf([0 0 0 0 0 0 a^3 0 0 0 0 0 0 0 0],a.m,a.prim_poly);
%r = gf([a^2 0 0 0 0 0 a^3 0 0 0 0 0 a^4 0 0],a.m,a.prim_poly);
%r = gf([a^6 0 0 0 0 0 a^3 0 0 0 0 0 a^4 0 0],a.m,a.prim_poly);
%r = gf([a^6 0 0 0 0 0 0 0 0 0 0 0 a^4 0 0],a.m,a.prim_poly);
r = gf([0 0 0 a^10 0 0 0 0 a^7 0 0 0 0 a^9 0],a.m,a.prim_poly);

ai = a.^(1:2*t);

fprintf('Horner scheme syndromes:');
s = gf(zeros(1,2*t),a.m,a.prim_poly);
rr = r(length(r):-1:1);
for i=1:length(rr)
    % calculate next iteration of polynomial evaluation
    for k=1:length(s)
        s(k) = s(k)*ai(k) + rr(i);
    end
end
s.x

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
degree_of_cx = length(cx); 
for i=1:length(cx)
    degree_of_cx = degree_of_cx-1;
    if cx(i) ~= 0
        break
    end
end

% calculate error evaluator polynomial
error_evaluator = gf(zeros(1,degree_of_cx),a.m,a.prim_poly);
for i=1:degree_of_cx
    tmps = gf(s(degree_of_cx+1-i:-1:1),a.m,a.prim_poly);
    tmpc = gf(cx(length(cx):-1:length(cx)-degree_of_cx+i),a.m,a.prim_poly);
    tmp = tmps.*tmpc;

    for k=1:length(tmp)
        error_evaluator(length(error_evaluator)+1-i) = error_evaluator(length(error_evaluator)+1-i) + tmp(k);
    end
end

% Forney's algorithm
% evaluate error evaluator at error locator roots

% Calculate numerators
eval_numerators = gf(zeros(size(error_evaluator)),a.m,a.prim_poly);
for i=1:length(error_locator_roots)
    % fprintf('Iteration: %i\n',i);
    for k=1:length(error_evaluator)
        eval_numerators(i) = eval_numerators(i) + error_evaluator(k)*error_locator_roots(i)^(k-1);
        %ee = error_evaluator(k);
        %elr = error_locator_roots(i);
        % fprintf('i %i k %i: %i %i\n',i,k,ee.x,elr.x);
    end
end

% Horner scheme for numerator calculation
% eval_numerators = gf(zeros(size(error_evaluator)),a.m,a.prim_poly);
% relr = error_locator_roots;
% rev = error_evaluator(length(error_evaluator):-1:1);
% for i=1:length(relr)
%     % print coefficient
%     elr = relr(i);
%     fprintf('Coefficient: %i',elr.x);
% 
%     % calculate next iteration of polynomial evaluation
%     for k=1:length(eval_numerators)
%         eval_numerators(k) = eval_numerators(k)*relr(k) + rev(i);
%     end
% 
%     % print numerators
%     % fprintf(file,' %i',eval_numerators.x);
%     % fprintf(file,'\n');
% end
% eval_numerators.x

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
ev = gf(zeros(size(error_locations)),a.m,a.prim_poly);
for i=1:length(error_locations)
    ev(i) = eval_numerators(i)*inv(eval_denominators(i));
end

eval_numerators_x = eval_numerators.x;
error_evaluator_x = error_evaluator.x;
eix = symbol_locations.x;
erx = error_locator_roots.x;
fprintf('Numerators %i\n',eval_numerators_x);

outputarray = [zeros(1,t-length(erx)) erx error_evaluator_x zeros(1,t-length(error_evaluator_x))];
fprintf('Testfile:\n');
fprintf('%i ',outputarray);
fprintf('\n');

fprintf(file,'%i ',outputarray);
fprintf(file,'\n');

fclose(file);

%write do file
file = fopen('../t_forney_calculator.do','w');
fprintf(file,'vsim vhdlib_tb(forney_calculator_tb)\n');
fprintf(file,'log -r /*\n');
fprintf(file,'do t_forney_calculator_wave.do\n');
fprintf(file,'run %i ns\n',300);
fclose(file);
