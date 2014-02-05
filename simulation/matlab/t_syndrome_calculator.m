clc;

file = fopen('../t_syndrome_calculator.txt','w');

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

no_of_symbols = 3;
new_word = 1;
fprintf(file,'%i',new_word);
new_word = 0;

for i=1:length(r)
    fprintf(file,' %i',rx(i));
    for k=1:length(sa)
        sa(k) = sa(k)*aa(k) + r(i);
    end
    if mod(i,no_of_symbols) == 0
        if new_word == 0
            fprintf(file,' %i',zeros(1,length(sa)));
        end
        fprintf(file,' %i',sa.x);
        fprintf(file,'\n');
        if i ~= length(r)
            fprintf(file,'%i',new_word);
        end
    end
end

fclose(file);

%write do file
file = fopen('../t_syndrome_calculator.do','w');
fprintf(file,'vsim vhdlib_tb(syndrome_calculator_tb)\n');
fprintf(file,'log -r /*\n');
fprintf(file,'do t_syndrome_calculator_wave.do\n');
fprintf(file,'run %i ns\n',300);
fclose(file);