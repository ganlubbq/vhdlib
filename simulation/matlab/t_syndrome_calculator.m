clc;

file = fopen('../t_syndrome_calculator.txt','w');

% alpha
ns = 6; % number of syndromes
gf_poly = 19;
m = floor(log2(gf_poly));
a = gf(2,m,gf_poly); %alpha
no_of_coefs = 3;
new_calc = 1;

% polynomial coefficients; descending order
c = gf([0 0 0 a^7 0 0 a^3 0 0 0 0 0 a^4 0 0],m,gf_poly);

% evaluate polynomials using Horner scheme
c = c(length(c):-1:1); % reverse
cx = c.x;

sv = gf(zeros(1,ns),m,gf_poly); % syndrome values
ev = a.^(1:ns); % evaluation values (powers of alpha element)


% iterate over coefficients
for i=1:length(c)
    if mod(i,no_of_coefs) == 1 || no_of_coefs == 1
      fprintf(file,'%i',new_calc);
      new_calc = 0;
    end
    
    % print coefficient    
    fprintf(file,' %i',cx(i));

    % calculate next iteration of polynomial evaluation
    for k=1:length(sv)
        sv(k) = sv(k)*ev(k) + c(i);
    end

    % if the number of symbols processed in parallel has been reached
    if mod(i,no_of_coefs) == 0
        % print syndromes
        fprintf(file,' %i',sv.x);
        fprintf(file,'\n');
    end

    if i == length(c)
        new_calc = 1;
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