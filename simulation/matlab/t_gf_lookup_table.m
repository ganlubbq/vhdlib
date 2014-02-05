clc;

file = fopen('../t_gf_lookup_table.txt','w');

mode = 3; % 1 = inverse, 2 = logarithm, 3 = exponentiation
gf_poly = 19;
m = floor(log2(gf_poly));

a = gf(2,m,gf_poly); %alpha

for i=0:10
    if mode == 1
        gfa = gf(randi([1,2^m-1]),m,gf_poly);
        gfb = inv(gfa);
        fprintf(file,'%i %i\n',gfa.x, gfb.x);
    elseif mode == 2
        e = randi([0,2^m-2]);
        gfa = a^e;
        gfb = gf(e,m,gf_poly);
        fprintf(file,'%i %i\n',gfa.x, gfb.x);
    elseif mode == 3
        e = randi([0,2^m-2]);
        gfa = gf(e,m,gf_poly);
        gfb = a^e;
        fprintf(file,'%i %i\n',gfa.x, gfb.x);
    end
end
fclose(file);

%write do file
file = fopen('../t_gf_lookup_table.do','w');
fprintf(file,'vsim vhdlib_tb(gf_lookup_table_tb)\n');
fprintf(file,'log -r /*\n');
fprintf(file,'do t_gf_lookup_table_wave.do\n');
fprintf(file,'run %i ns\n',300);
fclose(file);