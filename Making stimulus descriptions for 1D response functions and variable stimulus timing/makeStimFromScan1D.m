function params = makeStimFromScan1D(params,id)
% makeStimFromScan1D - Make stimulus from stored image matrix for solving
% retinotopic model or predicting BOLD response.
%
% params = makeStimFromScan1D(params,id);
%
% Notes: 
% 
%   This code was written with the intention of using files generated from
%   exptTools stimulus presentation code (such as 'ret'). If you run such
%   code and choose (1) save parameters, and (2) save image matrix, then
%   you will get two files in exactly the format required by this code.
%   Alternatively you can  generate the .mat files with the required
%   fields, as described below.
%
%   The two files the code will look for can be located anywhere with a
%   valid path. However, the GUI 'rmEditStimulusParameters' looks
%   specifically for files within a directory called '[My Project
%   directory]/Stimuli', and it looks for files that contain the string
%   'image' (for the image matrix) and 'param' (for the parameters file).
%
% Inputs:[x,y]=meshgrid(mygrid,mygrid);
%       id: scan number (integer)
%
%       params: a struct containing the following fields
%           (normally generated from GUI or stored in dataTYPES)
%
%          Required
%               params.stim(id).imFile*  (filename)
%               params.stim(id).paramsFile** (filename)
%               params.analysis.fieldSize (degrees, radius)
%               params.analysis.numberStimulusGridPoints (n points, radius)
%               params.analysis.sampleRate (degrees per point)
%
%          Optional
%               params.framePeriod (length of TR in s)
%               params.stim(id).nFrames (n TRs in scan)
%               params.prescanDuration (in TRs, not s)
%               params.stim(id).imFilter (default = 'binary');
%                   (see .../retinotopyModel/FilterDefinitions/ for 
%                       other filters)
%
%
%       *imFile:  imfile wil be loaded into struct 'I'
%           Required
%               I.images: an n x m x k matrix. n and m are the image size,
%                           k is the number of unique images.
%                TODO: allow RGB image matrices 
%
%       **paramsFile: paramsfile wil be loaded into struct 'P'.
%           Required
%               P.stimulus.seq: a vector indexing the image matrix I.images
%               P.stimulus.seqTiming: a vector of image onset times (in s)
%
%           Optional
%               P.params.display (screen calibration information)
%           Optional (but nec if not included in input params)
%               P.params.framePeriod (length of TR in s)
%               P.params.numImages (n TRs in scan)
%               P.params.prescanDuration (in s, not TRs)
%
%
% The basic steps are:
%   1. Load the parameter file and image matrix
%   2. Filter the images.
%       The images are saved as grayscale or RGB images, but as a predictor
%       for a BOLD response, we may want to binarize the images (i.e., draw
%       the stimulus aperture), or perform some other kind of filter such
%       as contrast energy. Default is binary.
%   3. Build a sampling grid.
%       (This will usually be coarser than the saved images.)
%   4. Downsample the images to the grid.
%   5. Average all the images within a TR.
%
%
%
% Warning:
% A source of potential confusion: There is an input argument 'params' and
% there is also a parameters file loaded into the structure P. These
% should not be confused. To make matters worse, the struct P has a
% subfield called params. Perhaps there is a better way to do this. But the
% reason for the current scheme is consistency with existing code: Similar
% functions like make8bars, makeWedges, etc, all input and output a struct
% called params. Hence it is useful to do so here. The parameters file that
% is loaded (and that also includes a subfield called 'params') is made by
% stimulus presentation code like 'ret'. Since those structures already
% exist, we use them without modification.
%
% 2008/09 JW: Wrote it.



if notDefined('params'),
    error('[%s]: Need params', mfilename);
end

if notDefined('id'),
    id = 1;
end

% Load the images and parameters from the scan
[P params] = subLoadImages(params, id);

% Make a sampling grid
uniqueVals=1;
if uniqueVals
    [x, y, params]  = subSamplingGridUnique(P, params);
else
    [x, y, params]  = subSamplingGrid(params);
end

%HACK to remove predicted responses to stimulus starting in feature tuning
%models where features are constant throughout the stimulus sequence.
% P.params.dotOrder=[P.params.dotOrder((end-23):(end-8)) P.params.dotOrder];
% params.stim(id).prescanDuration=(P.params.prescanDuration./P.params.tr)+16;

% get presentation order
stimorder = repmat(P.params.dotOrder(:,1),1,P.params.ncycles);

% make "images"
images = zeros(length(x),length(stimorder));
for n=1:length(P.params.dotOrder)
    % A test to determine if the params file has dotOrder includes whole numbers only, normally because it is in linear space, not log space.
    if ~uniqueVals && sum(mod(P.params.dotOrder(:,1), 1))==0 && mod(params.analysis.sampleRate,1)==0
        %     %for linear fit
        if P.params.dotOrder(n)>0
            images(P.params.dotOrder(n),n) = 1;
        end
    else
        %For log fit (params.dotOrder should be log transformed in the stimulus
        %file
        
        
        if uniqueVals;
            if min(size(P.params.dotOrder))==1
                if P.params.dotOrder(n)>=0
                    images(find(P.params.dotOrder(n)==x),n)=1;
                end
            else
                if P.params.dotOrder(n, id)>=0
                    images(find(P.params.dotOrder(n, id)==x),n)=1;
                end
            end
        else
            images(P.params.dotOrder(n)+params.analysis.sampleRate/2>x & P.params.dotOrder(n)-params.analysis.sampleRate/2<x,n) = 1;
        end
    end

end

% Done. Save the images and return
params.stim(id).images = single(images);

%Set params to avoid downsampling, treat each frame like a TR.
%Downsampling comes later, after HRF convolution. HRF needs to be
%updated to per-frame timing.
if isfield(P.params, 'dotTiming')
    params.stim(id).framePeriodReal=params.stim(id).framePeriod;
    params.stim(id).framePeriod=P.params.dotTiming(2);
    params.stim(id).nFramesReal=params.stim(id).nFrames;
    params.stim(id).nFrames=params.stim(id).framePeriodReal*(params.stim(id).nFrames/P.params.dotTiming(2));
    params.stim(id).prescanDurationReal=params.stim(id).prescanDuration;
    params.stim(id).prescanDuration = round(params.stim(id).prescanDuration* params.stim(id).framePeriodReal/ params.stim(id).framePeriod);
   
    if id==1
        params.analysis.HrfReal=params.analysis.Hrf;
        params.analysis.HrfMaxResponseReal=params.analysis.HrfMaxResponse;
    end
    params = hrfSet(params,'hrf');
    %[images, params]= subTemporalDownsample(I, P, params, id);
end

fprintf(1,'[%s]: Done.\n', mfilename);
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Subroutines %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%------------------------------------------------------------------
function [P params] = subLoadImages(params, id)
%------------------------------------------------------------------
fprintf(1,'[%s]: Loading images: %s...\n', mfilename, params.stim(id).paramsFile);
fprintf(1,'[%s]: Loading images for scan %d...\n', mfilename, id);

% load the stored params (these are different from the input arg params)
if ~checkfields(params, 'stim', 'paramsFile'),
    error('Need the experiment params file from scan');
end
% TODO: absolute path is stored. Perhaps store path relative to data directory.
paramsFile  =    params.stim(id).paramsFile;
if ~exist(paramsFile, 'file')
    [pth, fname ext] = fileparts(paramsFile);
    paramsFile = fullfile('Stimuli', [fname ext]);
end
P = load(paramsFile);

% reset params .fieldSize because it is the maximal number not stimulus
% size (unless this has been explicitly set)
if ~isfield(params.analysis, 'fieldSize')
    params.analysis.fieldSize = max(P.params.dotOrder);
end

end

%------------------------------------------------------------------
function [x, y, params] = subSamplingGrid (params)
%------------------------------------------------------------------
% Note: Currently the grid is made from the input struct 'params'.
% It also would be possible to make it from params saved from
% the experiment. However the visual angle might not be right in the stored
% files. So safer to set it manually in the GUI.

nSamples = params.analysis.numberStimulusGridPoints;
x = params.analysis.minFieldSize:params.analysis.sampleRate:params.analysis.fieldSize;
y = zeros(size(x));

% Update the sampling grid to reflect the sample points used.
params.analysis.X = x(:);
params.analysis.Y = zeros(size(x(:)));

% Verify that the grid is the expected size.
% FIX ME....
if length(params.analysis.X) ~= (1+nSamples*2),
    fprintf('[%s]: error in grid creation\n', mfilename);
end
end

function [x, y, params] = subSamplingGridUnique (P, params)
%------------------------------------------------------------------
% Note: Currently the grid is made from the input struct 'params'.
% It also would be possible to make it from params saved from
% the experiment. However the visual angle might not be right in the stored
% files. So safer to set it manually in the GUI.


x=sort(unique(P.params.dotOrder));
x=x(x>=0);
y = zeros(size(x));

% Update the sampling grid to reflect the sample points used.
params.analysis.X = x(:);
params.analysis.Y = zeros(size(x(:)));

end
