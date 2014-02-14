clc;

file = fopen('../t_gf_horner_evaluator.txt','w');

% alpha
ne = 6; % number of parallel evaluations
gf_poly = 19;
m = floor(log2(gf_poly));
a = gf(2,m,gf_poly); %alpha
no_of_symbols = 3;
new_calc = 1;

% polynomial coefficients; descending order
c = gf([0 0 0 a^7 0 0 a^3 0 0 0 0 0 a^4 0 0],m,gf_poly);

% evaluate polynomials using Horner scheme
c = c(length(c):-1:1); % reverse
cx = c.x;

rv = gf(zeros(1,ne),m,gf_poly); % result_values
ev = a.^(1:ne); % eval_values 


% iterate over coefficients
for i=1:length(c)
    if mod(i,no_of_symbols) == 1
      fprintf(file,'%i',new_calc);
      new_calc = 0;
    end
    
    % print coefficient    
    fprintf(file,' %i',cx(i));

    % calculate next iteration of polynomial evaluation
    for k=1:length(rv)
        rv(k) = rv(k)*ev(k) + c(i);
    end

    % if the number of symbols processed in parallel has been reached
    if mod(i,no_of_symbols) == 0
        % print eval_values
        fprintf(file,' %i',ev.x);

        % print start_values
        fprintf(file,' %i',zeros(1,length(rv)));

        % print result_values
        fprintf(file,' %i',rv.x);
        fprintf(file,'\n');
    end

    if i == length(c)
        new_calc = 1;
    end
end

fclose(file);

%write do file
file = fopen('../t_gf_horner_evaluator.do','w');
fprintf(file,'vsim vhdlib_tb(gf_horner_evaluator_tb)\n');
fprintf(file,'log -r /*\n');
fprintf(file,'do t_gf_horner_evaluator_wave.do\n');
fprintf(file,'run %i ns\n',300);
fclose(file);
