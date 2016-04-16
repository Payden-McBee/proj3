function [henkelElementsRow henkelElementsCol]= makeHenkel(pos,hankelIndex,henkelElementsRow,henkelElementsCol)

    henkelElementsRow(hankelIndex) = pos(1,1);
    henkelElementsCol(hankelIndex) = pos(1,2);

end

    