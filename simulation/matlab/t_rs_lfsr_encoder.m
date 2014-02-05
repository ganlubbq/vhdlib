clc;
file = fopen('../t_rs_lfsr_encoder.txt','w');

gpoly = gf([1 59 13 104 189 68 209 30 8 163 65 41 229 98 50 36 59],8);

msg = gf([randi([0 254],1,239) zeros(1,16)],8);
%msg = gf([16 zeros(1,254)],8);

[q,r] = deconv(msg,gpoly);

cw = msg + r;

for i=1:length(cw)
    x = cw(i);
    fprintf(file,'%i %i%i%i%i%i%i%i%i\n',i==1,bitget(x.x,8:-1:1));
end
fclose(file);

%write do file
file = fopen('../t_rs_lfsr_encoder.do','w');
fprintf(file,'vsim vhdlib_tb(rs_lfsr_encoder_tb)\n');
fprintf(file,'log -r /*\n');
fprintf(file,'do t_rs_lfsr_encoder_wave.do\n');
fprintf(file,'run %i us\n',3);
fclose(file);