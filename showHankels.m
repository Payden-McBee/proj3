function [HankR, HankC] = showHankels(Arow, Acol, brow, bcol, Crow, Ccol, pos)
 HankR = zeros(6,6);
 HankC = zeros(6,6);
         HankR(1:5,1:5) = Arow;
         HankR(6,1:5) = Crow;
         HankR(1:5,6) = brow;
         HankR(6,6) = pos(1,1);
       
         HankC(1:5,1:5) = Acol;
         HankC(6,1:5) = Ccol;
         HankC(1:5,6) = bcol;
         HankC(6,6) = pos(1,2);