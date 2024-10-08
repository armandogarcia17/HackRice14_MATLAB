% This is take home Exercise 6 as part of the Pocket AI and IoT workshop 
% debuted at the Grace Hopper Celebration 2019, 
% and presented at the Society of Women Engineers WE19

% In this exercise, you are going to experiment with KNN classifier to try
% different parameters in order to improve the accuracy of the
% classification result.
% Steps:
% 1. Look for TODO in comments:
%    a. Change distance metric
%    b. Change KNN (nearest K value neighbor)

% Clear all previously collected data and plots
clear m; clearvars -except teamID; close all; 

% Add the helper files to your path so that
% you can use them in this file. 
addpath(fullfile(pwd,'helperFiles'));

% Collect data for 30 secs at a frequency
% of 60 Hz
secs = 30;
sampleRate = 60;
m = CollectData(sampleRate, secs);

% Retrieve the XYZ acceleration data
% and timestamps from the device

[a, t] = accellog(m);

% Separate the acceleration into the 
% <X, Y, Z> vectors

x = a(:,1);
y = a(:,2);
z = a(:,3);

% Step 2: Extract features from 
% the collected data by
% a. Resampling the data so that it evenly spaced
% b. Parsing the data in 5s intervals
% c. Extracting 2 features

% Initialize parameters

% Detection window length
windowLength = 5;

% Number of windows between consecutive 
% detections
detectionInterval = 1;

% Data from phone may not be uniformly 
% sampled, so it will be resampled at
% this rate.
uniformSampleRate = 60; % Hz. 

% Resampling the raw data to obtain
% uniformly sampled acceleration data
newTime = 0:1/60:(t(end)-t(1));
x = interp1(t,x,newTime);
y = interp1(t,y,newTime);
z = interp1(t,z,newTime);
a = [x;y;z]';
t = newTime;

i = 1;
lastFrame = find(t>(t(end)-windowLength-0.005),1);

% Set default starting activity to idling
lastDetectedActivity = 0;

frameIndex = [];
features = [];

% Parse through the data in 5 second 
% windows and detect activity for each 5
% second window
while (i < lastFrame)

    % Calculate the start and end indices
    % of the 5-second frame
    startIndex = i;
    frameIndex(end+1,:) = startIndex;
    t0 = t(startIndex);
    nextFrameIndex = ...
        find(t > t0 + detectionInterval);
    nextFrameIndex = nextFrameIndex(1) - 1;
    stopIndex = ...
        find(t > t0 + windowLength);
    stopIndex = stopIndex(1) - 1;
    
    % Use the indices to get the frame from
    % the accelerometer data
    frameData = ...
        a(startIndex:stopIndex, :, :);
    frameTime = ...
        t(startIndex:stopIndex);
    
    % Extract 2 features from the frame
    features(end+1,:) = extractSensorFeatures(...
        frameData,...
        uniformSampleRate);

    i = nextFrameIndex + 1;    
    
 end        

% Step 3: Train the model

[X,Y, dataMin, dataRange] = getTrainingData();

mdl = fitcknn(X,Y);

%Experimenting values:

%% TODO: There are different metrics that can be used to further improve the
% accuracy of the classification results
% See doc for examples: https://www.mathworks.com/help/stats/fitcknn.html
% Change distance: 
% Try: minkowski, hamming, euclidean, cityblock, chebychev etc. 
mdl.Distance = [];

%% TODO: Change number of nearest neighbors:
% You can choose from 1 to 800 (max number of datapoints available). 
knnK = 10; 
mdl.NumNeighbors = [];

%% Step 4: Predict the activity using the 
% extracted features

result = [];
score = [];    

numFrames = size(features,1);
for i=1:numFrames
    
    % Get one frame's features
    frameFeatures = features(i, :);
    
    % Normalize the features
    frameFeatures = ...
        (frameFeatures - dataMin) ./ dataRange;
    
    [frameActivity,frameScore] = ...
        predict(mdl, frameFeatures);
    
    % Scores reported by KNN classifier is 
    % ranging from 0 to 1. Higher score means
    % greater confidence of detection.
    if max(frameScore) < 0.90 || ... 
        frameActivity ~= lastDetectedActivity 
    
        % Set result to transition
        result(end+1, :) = -10; 
    else
        result(end+1, :) = frameActivity;
    end
    
    lastDetectedActivity = frameActivity;
    score(end+1, :) = frameScore;

end


% Step 6: Plot raw data and results

% Get the frames in which you were doing
% each activity
resWalk =(result == 2);
resRun  =(result == 3);
resIdle =(result == 0);
resUnknown =(result == -10);

% Get the time in which you were doing
% each activity
tWalk   = t(frameIndex(resWalk));
tWalkSum = numel(tWalk);

tRun    = t(frameIndex(resRun));
tRunSum = numel(tRun);

tIdle   = t(frameIndex(resIdle));
tIdleSum = numel(tIdle);

tTransition = t(frameIndex(resUnknown));

% Plot  the activities you performed over time
plotPredictedActivity(tWalk, tRun, tIdle, tTransition, windowLength);    

