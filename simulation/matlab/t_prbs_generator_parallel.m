clear;
clc;
file = fopen('../t_prbs_generator_parallel.txt','w');

poly = [1 0 0 1 0 1];
m = length(poly)-1;
w = 7; % data width

seed = gf(ones(1,w),1);

a=seed;
b = gf(horzcat(poly(2:m+1)',vertcat(eye(m-1,m-1),zeros(1,m-1))),1);

d = gf(zeros(m,w),1);
for i=1:w
    c = b^i;
    d(:,w+1-i) = c(:,1);
end

iterations = 10;
e = seed;
for i=1:iterations
    fprintf(file,'%i',e.x);
    e = e(1,1:m)*d;
    fprintf(file,' ');
    fprintf(file,'%i',e.x);
    fprintf(file,'\n');
end

fclose(file);

%write do file
file = fopen('../t_prbs_generator_parallel.do','w');
fprintf(file,'vsim vhdlib_tb(prbs_generator_parallel_tb)\n');
fprintf(file,'log -r /*\n');
fprintf(file,'do t_prbs_generator_parallel_wave.do\n');
fprintf(file,'run %i ns\n',iterations*10+10);
fclose(file);
