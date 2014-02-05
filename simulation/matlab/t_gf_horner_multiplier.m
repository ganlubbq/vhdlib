%gf_horner_multiplier
clc;

file = fopen('../t_gf_horner_multiplier.txt','w');

gf_poly = 19;
m = floor(log2(gf_poly));

a = gf(2,m,gf_poly); %alpha

for i=0:10
    gfa = gf(randi([0,2^m-1]),m,gf_poly);
    gfb = gf(randi([0,2^m-1]),m,gf_poly);
    gfc = gfb*a+gfa;
    fprintf(file,'%i %i %i\n',gfa.x, gfb.x, gfc.x);
end
fclose(file);

%write do file
file = fopen('../t_gf_horner_multiplier.do','w');
fprintf(file,'vsim vhdlib_tb(gf_horner_multiplier_tb)\n');
fprintf(file,'log -r /*\n');
fprintf(file,'do t_gf_horner_multiplier_wave.do\n');
fprintf(file,'run %i ns\n',300);
fclose(file);