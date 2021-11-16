
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% I is the input image
% Level is the extent of compression. It should be in between 1 and 256.
% Level=1 produces to maximum compression and Level=256 produces minimum compression
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc;
clear all;
close all;

I = imread('image1.jpg');
Level = 16;
for i=1:size(I,3)
 cI(:,:,i) = compressImage(I(:,:,i),Level);
end
figure,subplot(1,2,1),imshow(I),title('Original Image');
       subplot(1,2,2),imshow(cI),title('Compressed Image BASED ON ENTROPY');
       %% 
       
B1 = dec2bin(cI);


display('Entropy of compressed Image According to Entropy:');
display(entropy(cI));
display('Entropy of origianl image  : ');
display(entropy(I)) ;
%% 
scale = 1;                       % Image scaling factor
origSize = size(cI);            % Original input image size
scaledSize = max(floor(scale.*origSize(1:2)),1); % Calculate new image size
heightIx = min(round(((1:scaledSize(1))-0.5)./scale+0.5),origSize(1));
widthIx = min(round(((1:scaledSize(2))-0.5)./scale+0.5),origSize(2));
fData = cI(heightIx,widthIx,:); % Resize image
imsize = size(fData);              % Store new image size
txImage = fData(:);



% Setup handle for image plot
if ~exist('imFig', 'var') || ~ishandle(imFig)
    imFig = figure;
    imFig.NumberTitle = 'off';
    imFig.Name = 'Image Plot';
    imFig.Visible = 'off';
else
    clf(imFig); % Clear figure
    imFig.Visible = 'off';
end

% Setup Spectrum viewer
spectrumScope = dsp.SpectrumAnalyzer( ...
    'SpectrumType',    'Power density', ...
    'SpectralAverages', 10, ...
    'YLimits',         [-130 -40], ...
    'Title',           'Received Baseband WLAN Signal Spectrum', ...
    'YLabel',          'Power spectral density');

% Setup the constellation diagram viewer for equalized WLAN symbols
constellation = comm.ConstellationDiagram('Title','Equalized WLAN Symbols',...
                                'ShowReferenceConstellation',false);
                            
%  Initialize SDR device
deviceNameSDR = 'E3xx'; % Set SDR Device

txGain = -10;

% Plot transmit image
figure(imFig);
imFig.Visible = 'on';
subplot(211);
    imshow(fData);
    title('Transmitted Image');
subplot(212);
    title('Received image will appear here...');
    set(gca,'Visible','off');
    set(findall(gca, 'type', 'text'), 'visible', 'on');

pause(1); % Pause to plot Tx image  

msduLength = 2304; % MSDU length in bytes
numMSDUs = ceil(length(txImage)/msduLength);
padZeros = msduLength-mod(length(txImage),msduLength);
txData = [txImage; zeros(padZeros,1)];
txDataBits = double(reshape(de2bi(txData, 8)', [], 1));

% Divide input data stream into fragments
bitsPerOctet = 8;
data = zeros(0, 1);

for ind=0:numMSDUs-1

    % Extract image data (in octets) for each MPDU
    frameBody = txData(ind*msduLength+1:msduLength*(ind+1),:);

    % Create MAC frame configuration object and configure sequence number
    cfgMAC = wlanMACFrameConfig('FrameType', 'Data', 'SequenceNumber', ind);

    % Generate MPDU
    [mpdu, lengthMPDU] = wlanMACFrame(frameBody, cfgMAC);

    % Convert MPDU bytes to a bit stream
    psdu = reshape(de2bi(hex2dec(mpdu), 8)', [], 1);

    % Concatenate PSDUs for waveform generation
    data = [data; psdu]; %#ok<AGROW>

end

nonHTcfg = wlanNonHTConfig;         % Create packet configuration
nonHTcfg.MCS = 6;                   % Modulation: 64QAM Rate: 2/3
nonHTcfg.NumTransmitAntennas = 1;   % Number of transmit antenna
chanBW = nonHTcfg.ChannelBandwidth;
nonHTcfg.PSDULength = lengthMPDU;   % Set the PSDU length

sdrTransmitter = sdrtx(deviceNameSDR); % Transmitter properties

% Resample the transmit waveform at 30MHz
fs = wlanSampleRate(nonHTcfg); % Transmit sample rate in MHz
osf = 1.5;                     % OverSampling factor

sdrTransmitter.BasebandSampleRate = fs*osf;
sdrTransmitter.CenterFrequency = 2.432e9;  % Channel 5
sdrTransmitter.Gain = txGain;
sdrTransmitter.ChannelMapping = 1;         % Apply TX channel mapping
sdrTransmitter.ShowAdvancedProperties = true;
sdrTransmitter.BypassUserLogic = true;

% Initialize the scrambler with a random integer for each packet
scramblerInitialization = randi([1 127],numMSDUs,1);

% Generate baseband NonHT packets separated by idle time
txWaveform = wlanWaveformGenerator(data,nonHTcfg, ...
    'NumPackets',numMSDUs,'IdleTime',20e-6, ...
    'ScramblerInitialization',scramblerInitialization);

% Resample transmit waveform
txWaveform  = resample(txWaveform,fs*osf,fs);

fprintf('\nGenerating WLAN transmit waveform:\n')

% Scale the normalized signal to avoid saturation of RF stages
powerScaleFactor = 0.8;
txWaveform = txWaveform.*(1/max(abs(txWaveform))*powerScaleFactor);
% Cast the transmit signal to int16, this is the native format for the SDR
% hardware
txWaveform = int16(txWaveform*2^15);

% Transmit RF waveform
sdrTransmitter.transmitRepeat(txWaveform);

%reciever
sdrReceiver = sdrrx(deviceNameSDR);
sdrReceiver.BasebandSampleRate = sdrTransmitter.BasebandSampleRate;
sdrReceiver.CenterFrequency = sdrTransmitter.CenterFrequency;
sdrReceiver.OutputDataType = 'double';
sdrReceiver.ChannelMapping = 1; % Configure Rx channel map
sdrReceiver.ShowAdvancedProperties = true;
sdrReceiver.BypassUserLogic = true;

% Configure receive samples equivalent to twice the length of the
% transmitted signal, this is to ensure that PSDUs are received in order.
% On reception the duplicate MAC fragments are removed.
samplesPerFrame = length(txWaveform);
requiredCaptureLength = samplesPerFrame*2;
spectrumScope.SampleRate = sdrReceiver.BasebandSampleRate;

% Get the required field indices within a PSDU
indLSTF = wlanFieldIndices(nonHTcfg,'L-STF');
indLLTF = wlanFieldIndices(nonHTcfg,'L-LTF');
indLSIG = wlanFieldIndices(nonHTcfg,'L-SIG');
Ns = indLSIG(2)-indLSIG(1)+1; % Number of samples in an OFDM symbol

% SDR Capture
fprintf('\nStarting a new RF capture.\n')

% Store twice the length of WLAN transmitted packet worth of
% samples, capturedData holds requiredCaptureLength number of baseband
% WLAN samples
capturedData = capture(sdrReceiver, requiredCaptureLength, 'Samples');


%Reconstruct Image

if ~(isempty(fineTimingOffset)||isempty(pktOffset))&& ...
        (numMSDUs==(numel(packetSeq)-1))
    % Remove the duplicate captured MAC fragment
    rxBitMatrix = cell2mat(rxBit);
    rxData = rxBitMatrix(1:end,1:numel(packetSeq)-1);

    startSeq = find(packetSeq==0);
    rxData = circshift(rxData,[0 -(startSeq(1)-1)]);% Order MAC fragments

    % Perform bit error rate (BER) calculation
    bitErrorRate = comm.ErrorRate;
    err = bitErrorRate(double(rxData(:)), ...
                    txDataBits(1:length(reshape(rxData,[],1))));
    fprintf('  \nBit Error Rate (BER):\n');
    fprintf('          Bit Error Rate (BER) = %0.5f.\n',err(1));
    fprintf('          Number of bit errors = %d.\n', err(2));
    fprintf('    Number of transmitted bits = %d.\n\n',length(txDataBits));

    % Recreate image from received data
    fprintf('\nConstructing image from received data.\n');

    decdata = bi2de(reshape(rxData(1:length(txImage)*bitsPerOctet), 8, [])');

    receivedImage = uint8(reshape(decdata,imsize));
    % Plot received image
    if exist('imFig', 'var') && ishandle(imFig) % If Tx figure is open
        figure(imFig); subplot(212);
    else
        figure; subplot(212);
    end
    imshow(receivedImage);
    title(sprintf('Received Image'));
end