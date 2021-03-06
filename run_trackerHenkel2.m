
%  Exploiting the Circulant Structure of Tracking-by-detection with Kernels
%
%  Main script for tracking, with a gaussian kernel.
%
%  Jo�o F. Henriques, 2012
%  http://www.isr.uc.pt/~henriques/
close all
clear
clc

%choose the path to the videos (you'll be able to choose one with the GUI)
base_path = 'C:\Users\Payden McBee\Documents\NEU\NEUclasses\CompVision\proj3\tracker_release\imgs';
%base_path = 'tracker_release/imgs/';


%parameters according to the paper
padding = 1;					%extra area surrounding the target
output_sigma_factor = 1/16;		%spatial bandwidth (proportional to target)
sigma = 0.2;					%gaussian kernel bandwidth
lambda = 1e-2;					%regularization
interp_factor = 0.075;			%linear interpolation factor for adaptation

% parameters of occlusion GUI
position = [1 1];
text_str = 'Occlusion Detected!';
box_color = {'red'};
occThresh = 10;
objOccluded = false; 

% Henkel Params
Arow = zeros(5,5);
brow = zeros(5,1);
Crow = zeros(1,5);
Acol = zeros(5,5);
bcol = zeros(5,1);
Ccol = zeros(1,5);
newPos = [0 0]; 
HankelMade = false; 
HankelIndex = 1; %increment to 10 
henkelElementsRow = zeros(1,10);
henkelElementsCol = zeros(1,10);

%notation: variables ending with f are in the frequency domain.

%ask the user for the video
video_path = choose_video(base_path);
if isempty(video_path), return, end  %user cancelled
[img_files, pos, target_sz, resize_image, ground_truth, video_path] = ...
	load_video_info(video_path);


%window size, taking padding into account
sz = floor(target_sz * (1 + padding));

%desired output (gaussian shaped), bandwidth proportional to target size
output_sigma = sqrt(prod(target_sz)) * output_sigma_factor;
[rs, cs] = ndgrid((1:sz(1)) - floor(sz(1)/2), (1:sz(2)) - floor(sz(2)/2));
y = exp(-0.5 / output_sigma^2 * (rs.^2 + cs.^2));
yf = fft2(y);

%store pre-computed cosine window
cos_window = hann(sz(1)) * hann(sz(2))';

time = 0;  %to calculate FPS
positions = zeros(numel(img_files), 2);  %to calculate precision

for frame = 1:numel(img_files),
	%load image
	im = imread([video_path img_files{frame}]);
	if size(im,3) > 1,
		im = rgb2gray(im);
	end
	if resize_image,
		im = imresize(im, 0.5);
	end
	
	tic()
	
	%extract and pre-process subwindow
	x = get_subwindow(im, pos, sz, cos_window);
	
	if frame > 1,
		%calculate response of the classifier at all locations
		k = dense_gauss_kernel(sigma, x, z);
		response = real(ifft2(alphaf .* fft2(k)));   %(Eq. 9)
		
		%target location is at the maximum response
		[row, col] = find(response == max(response(:)), 1);
		pos = pos - floor(sz/2) + [row, col];
        
        %detect if occluded, calculate PSR (peal to sidelobe ratio)            
        peakWinSizeRow = round(size(response,1)*0.15);
        peakWinSizeCol = round(size(response,2)*0.15);
        numSLpix = (size(response,1)*size(response,2))-peakWinSizeRow*peakWinSizeCol;
        g_max = max(response(:));
        sumResponse = sum(sum(response));
        sumPeakWin = sum(sum(response(row-peakWinSizeRow+1:row+peakWinSizeRow,col-peakWinSizeCol+2:col+peakWinSizeCol)));
        meanSideLobe = (sumResponse - sumPeakWin)/numSLpix;        
        
        meanSLvector = ones(size(response,1),size(response,2)).*meanSideLobe;
        responseSL = response;
        responseSL(row-5:row+5,col-5:col+5) = meanSideLobe; %to remove response of max window
        varSideLobe = (sum(sum((meanSLvector - responseSL).^2))/(numSLpix-1))^(1/2); % not correct, need to take out max window
        PSR(frame) = (g_max - meanSideLobe) / varSideLobe;
        
        if frame == 2
            occThresh = 0.6*PSR(frame)
        end
        if PSR(frame) < occThresh & HankelMade == true
            objOccluded = true;
            disp('Object Occluded')
        else
            objOccluded = false; 
            disp('Object NOT Occluded')
        end 
    end
    
    if objOccluded
        color = 'r';
    else
         color = 'g';
    end
	   
    if ~HankelMade
        if HankelIndex < 11
            [henkelElementsRow, henkelElementsCol]= makeHenkel(pos,HankelIndex,henkelElementsRow,henkelElementsCol)
            HankelIndex = HankelIndex + 1;
        else
            HankelMade = true;
            [Arow, Acol, brow, bcol, Crow, Ccol] = assembleSubHenkels(henkelElementsRow, henkelElementsCol);
        end
    end
    if HankelMade
       if ~objOccluded 
         [henkelElementsRow, henkelElementsCol] = incrementHankel( henkelElementsRow, henkelElementsCol, pos );
         [Arow, Acol, brow, bcol, Crow, Ccol] = assembleSubHenkels(henkelElementsRow, henkelElementsCol);
         [HankR, HankC] = showHankels(Arow, Acol, brow, bcol, Crow, Ccol, pos);
         HankC;
         label = 'Corrected';
       else
         if var(Crow)>2 %if there isn't much movement and occlused, assume location stays constant
         %vrow = Arow\brow
         vrow = (Arow'*Arow)\Arow'*brow;
         posRow =Crow*vrow;
         else
             posRow = Crow(5);
         end
         
         if var(Ccol)>2
         %vcol = Acol\bcol;
         vcol = (Acol'*Acol)\Acol'*bcol;
         posCol = Ccol*vcol
         else
             posCol = Ccol(5);
         end
         
         pos = [round(posRow), round(posCol)];
         [henkelElementsRow, henkelElementsCol] = incrementHankel( henkelElementsRow, henkelElementsCol, pos )
         [Arow, Acol, brow, bcol, Crow, Ccol] = assembleSubHenkels(henkelElementsRow, henkelElementsCol);
         [HankR, HankC] = showHankels(Arow, Acol, brow, bcol, Crow, Ccol, pos);
         HankC
         label = 'Predicted';
       end  
    end
    if ~objOccluded %if object is occluded, do not train classifier    
        %get subwindow at current estimated target position, to train classifer
        x = get_subwindow(im, pos, sz, cos_window);
	
        %Kernel Regularized Least-Squares, calculate alphas (in Fourier domain)
        k = dense_gauss_kernel(sigma, x);
        new_alphaf = yf ./ (fft2(k) + lambda);   %(Eq. 7)
        new_z = x;
	
        if frame == 1,  %first frame, train with a single image
            alphaf = new_alphaf;
            z = x;
        else
            %subsequent frames, interpolate model
            alphaf = (1 - interp_factor) * alphaf + interp_factor * new_alphaf;
            z = (1 - interp_factor) * z + interp_factor * new_z;
        end
    end
	
	%save position and calculate FPS
	positions(frame,:) = pos;
	time = time + toc();
	
	%visualization
	rect_position = [pos([2,1]) - target_sz([2,1])/2, target_sz([2,1])];
	if frame == 1,  %first frame, create GUI
		figure('NumberTitle','off', 'Name',['Tracker - ' video_path])
		im_handle = imshow(im, 'Border','tight', 'InitialMag',200);
		rect_handle = rectangle('Position',rect_position, 'EdgeColor','g');
	else
		try  %subsequent frames, update GUI
            if objOccluded
                imDisp = insertText(im,position,text_str,'FontSize',18,'BoxColor',box_color,'BoxOpacity',0.4,'TextColor','white');
            else
                imDisp = im;
            end
			set(im_handle, 'CData', imDisp)
			set(rect_handle, 'Position', rect_position,'EdgeColor',color)            
		catch  %#ok, user has closed the window
			return
		end
	end
	
	drawnow
 	%pause(0.02)  %uncomment to run slower
end

if resize_image, positions = positions * 2; end

disp(['Frames-per-second: ' num2str(numel(img_files) / time)])

%show the precisions plot
show_precision(positions, ground_truth, video_path)