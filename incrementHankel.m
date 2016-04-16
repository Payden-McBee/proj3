function [ henkelElementsRow, henkelElementsCol] = incrementHankel( henkelElementsRow, henkelElementsCol, pos )
henkelElementsRow(1:9) = henkelElementsRow(2:10);
henkelElementsCol(1:9) = henkelElementsRow(2:10);
henkelElementsCol(10) = pos(1,2);
henkelElementsRow(10) = pos(1,1);