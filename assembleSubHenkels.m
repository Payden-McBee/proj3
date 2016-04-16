function [Arow Acol brow bcol Crow Ccol] = assembleSubHenkels(henkelElementsRow, henkelElementsCol)
for i=1:5
    Arow(i,1:5) =  henkelElementsRow(i:i+4);
    Acol(i,1:5) =  henkelElementsCol(i:i+4);
end
brow = henkelElementsRow(6:10)';
bcol = henkelElementsCol(6:10)';
Crow = henkelElementsRow(6:10);
Ccol = henkelElementsCol(6:10);