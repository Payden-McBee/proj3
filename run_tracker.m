
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
base_path = 'tracker_release/imgs/';%'./data/';%


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
occThresh = 35;

% Kalman filter
kalmanFilter = []; isTrackInitialized = false;
objOccluded = false;

%notation: variables ending with f are in the frequency domain.

%ask the user for the video
video_path = choose_video(base_path);
if isempty(video_path), return, end  %user cancelled
[img_files, trackedLocation, target_sz, resize_image, ground_truth, video_path] = ...
	load_video_info(video_path);


%window size, taking padding into account
sz = floor(target_sz * (1 + padding));

%subwindow 

%desired output (gaussian shaped), bandwidth proportional to target size
output_sigma = sqrt(prod(target_sz)) * output_sigma_factor;
[rs, cs] = ndgrid((1:sz(1)) - floor(sz(1)/2), (1:sz(2)) - floor(sz(2)/2));
y = exp(-0.5 / output_sigma^2 * (rs.^2 + cs.^2));
yf = fft2(y);

%store pre-computed cosine window
cos_window = hann(sz(1)) * hann(sz(2))';


time = 0;  %to calculate FPS
positions = zeros(numel(img_files), 2);  %to calculate precision

PSR = zeros(numel(img_files),1);
PSR(1) = occThresh + 1;

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
	x = get_subwindow(im, trackedLocation, sz, cos_window);
	
	if frame > 1
		%calculate response of the classifier at all locations
		k = dense_gauss_kernel(sigma, x, z);
		response = real(ifft2(alphaf .* fft2(k)));   %(Eq. 9)
		
		%target location is at the maximum response
        [row, col] = find(response == max(response(:)), 1);
        trackedLocation = trackedLocation - floor(sz/2) + [row, col];
        
        %detect if occluded, calculate PSR (peal to sidelobe ratio)            
        peakWinSizeRow = round(size(response,1)*0.15);
        peakWinSizeCol = round(size(response,2)*0.15);
        numSLpix = (size(response,1)*size(response,2))-peakWinSizeRow*peakWinSizeCol;
        g_max = max(response(:));
        sumResponse = sum(sum(response));
        sumPeakWin = sum(sum(response(row-peakWinSizeRow:row+peakWinSizeRow,col-peakWinSizeCol:col+peakWinSizeCol)));
        meanSideLobe = (sumResponse - sumPeakWin)/numSLpix;        
        
        meanSLvector = ones(size(response,1),size(response,2)).*meanSideLobe;
        responseSL = response;
        responseSL(row-5:row+5,col-5:col+5) = meanSideLobe; %to remove response of max window
        varSideLobe = (sum(sum((meanSLvector - responseSL).^2))/(numSLpix-1))^(1/2); % not correct, need to take out max window
        PSR(frame) = (g_max - meanSideLobe) / varSideLobe;
        if PSR(frame) < occThresh
            objOccluded = true;
        else
            objOccluded = false; 
        end 
        
        
    end
    
    isObjectDetected = ~objOccluded; 
    if objOccluded
        color = 'r';
    else
         color = 'g';
         detectedLocation = trackedLocation;
    end
     
    if ~isTrackInitialized
       if isObjectDetected
         MotionModel = 'ConstantAcceleration';
         InitialLocation = detectedLocation;
         InitialEstimateError = [1 1 1]*1e8; %suggested noise and error from MATLAB
         MotionNoise = [1, 1, 1];
         MeasurementNoise = 85;
         kalmanFilter = configureKalmanFilter(MotionModel,InitialLocation,InitialEstimateError,MotionNoise,MeasurementNoise);
         isTrackInitialized = true;
         
         %get subwindow at current estimated target position, to train classifer
         %only train classifier if not occluded
         x = get_subwindow(im, trackedLocation, sz, cos_window);
    
	     %Kernel Regularized Least-Squares, calculate alphas (in Fourier domain)
	     k = dense_gauss_kernel(sigma, x);
	     new_alphaf = yf ./ (fft2(k) + lambda);   %(Eq. 7)
	     new_z = x;
         %first frame, train with a single image
		 alphaf = new_alphaf;
		 z = x;
       end
     else
       if isObjectDetected
         predict(kalmanFilter);
         trackedLocation = correct(kalmanFilter, detectedLocation);
         label = 'Corrected';
         %get subwindow at current estimated target position, to train classifer
         %only train classifier if not occluded
         x = get_subwindow(im, trackedLocation, sz, cos_window);
    
	     %Kernel Regularized Least-Squares, calculate alphas (in Fourier domain)
	     k = dense_gauss_kernel(sigma, x);
	     new_alphaf = yf ./ (fft2(k) + lambda);   %(Eq. 7)
	     new_z = x;
         
         %subsequent frames, interpolate model
		 alphaf = (1 - interp_factor) * alphaf + interp_factor * new_alphaf;
		 z = (1 - interp_factor) * z + interp_factor * new_z;
       else
         trackedLocation = predict(kalmanFilter);
         label = 'Predicted';
       end
     end

	%save trackedLocationition and calculate FPS
	positions(frame,:) = trackedLocation;
	time = time + toc();

	%visualization
	rect_position = [trackedLocation([2,1]) - target_sz([2,1])/2, target_sz([2,1])];
	if frame == 1,  %first frame, create GUI
		figure('NumberTitle','off','Name',['Tracker - ' video_path])        
   		im_handle = imshow(im, 'Border','tight', 'InitialMag',200);
		rect_handle = rectangle('Position',rect_position, 'EdgeColor','r');
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
 	pause(0.02)  %uncomment to run slower
end

if resize_image, positions = positions * 2; end

disp(['Frames-per-second: ' num2str(numel(img_files) / time)])

%show the precisions plot
show_precision(positions, ground_truth, video_path)

