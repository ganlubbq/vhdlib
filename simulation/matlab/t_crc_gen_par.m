clc;
file = fopen('../t_crc_gen_par.txt','w');

%CRC32 polynomial
gpoly = gf([1 0 0 0 0 0 1 0 0 1 1 0 0 0 0 0 1 0 0 0 1 1 1 0 1 1 0 1 1 0 1 1 1],1);

dw = 8;
len = 8*dw-32;
da = randi([0 1],1,len);

for i=dw:dw:length(da)
    [q,r] = deconv(gf([da(1:i) zeros(1,32)],1),gpoly);
    bin2hex(r.x);
    rx = r.x;
    for j=dw-1:-1:0
        fprintf(file,'%i',da(i-j));
    end
    fprintf(file,' %i%i%i%i%i%i%i%i%i%i%i%i%i%i%i%i%i%i%i%i%i%i%i%i%i%i%i%i%i%i%i%i\n',rx(length(r)-31:length(r)));
end

fclose(file);

%write do file
file = fopen('../t_crc_gen_par.do','w');
fprintf(file,'vsim vhdlib_tb(crc_gen_par_tb)\n');
fprintf(file,'log -r /*\n');
fprintf(file,'do t_crc_gen_par_wave.do\n');
fprintf(file,'run %i ns\n',length(da)/dw*10+10);
fclose(file);