clc;

file = fopen('../t_berlekamp_massey_calculator.txt','w');

%alpha
t = 3;
gf_poly = 19;
m = floor(log2(gf_poly));
a = gf(2,m,gf_poly); %alpha

%received vector
r = gf([0 0 0 a^7 0 0 a^3 0 0 0 0 0 a^4 0 0],m,gf_poly);
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

fprintf(file,'%i ',cx.x); % C(x)

fclose(file);

%write do file
file = fopen('../t_berlekamp_massey_calculator.do','w');
fprintf(file,'vsim vhdlib_tb(berlekamp_massey_calculator_tb)\n');
fprintf(file,'log -r /*\n');
fprintf(file,'do t_berlekamp_massey_calculator_wave.do\n');
fprintf(file,'run %i ns\n',300);
fclose(file);