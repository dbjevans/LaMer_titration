fclose('all');
clear variables

% Create phreeqc COM object
iphreeqc = actxserver('IPhreeqcCOM.Object');    % create PHREEQC COM object
% define database folder
dirP = 'C:\Program Files (x86)\USGS\IPhreeqcCOM 3.7.3-15968\database';

% Read in metadata file
metaData = readtable('metadata_titration.csv');
f = waitbar(0,'running...');
for i = 58:height(metaData)
    waitbar(i/height(metaData),f)
if ~isempty(metaData.calibration_file{i})

try

if strcmp(metaData.SW(i),'NaHCO3')==1 || ...
        strncmp(metaData.SW(i),'NaCl',4)==1
    dbStr = '\phreeqc.dat';
else
    dbStr = '\pitzer_clegg2023_aa6.dat';
end
iphreeqc.LoadDatabase([dirP dbStr]);

% delete calibration data from previous experiment
clear calData

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Read in and process calibration data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Read in calibration data
dirF = 'C:\Users\evans\Data\Earth_Science\co-author\Anthea\titratio_processing_revised_script\calibration-files';
FileName = [metaData.calibration_file{i} '.csv'];
      
tempFN = [dirF '\' FileName];
%%% TEMP
% copy to new folder
saveDirCal = 'C:\Users\evans\Data\Earth_Science\co-author\Anthea\titratio_processing_revised_script\Arns_et_al_2026_Matlab_titration_data_processing\calibration_data';
copyfile(tempFN,saveDirCal)
tempCalData = readtable(tempFN,'VariableNamingRule','preserve');

% Find location of second data block
CalData2Loc = isnan(tempCalData{:,1});
CalData2Loc = find(CalData2Loc,1);

% Determine whether pH or Ca data comes first
fid = fopen(tempFN);
fgets(fid); % Scroll down to the determiner
fgets(fid);
fgets(fid);
fline = fgets(fid);
CalData1Type = strcmp('MEAS U',fline(1:6)); % 1 if Ca first, 0 if pH first

% Separate the two data blocks
CalDataBlock1 = tempCalData(1:CalData2Loc-1,:);
CalDataBlock2 = tempCalData(CalData2Loc+2:height(tempCalData),:);

% Collate the calibration data. The Tiamo method was updated several times
% over the course of the experiments reported here, such that several
% formats of the raw csv files are present, dealt with by the block of code
% below

% The format of the extracted data blocks are
%   CaCalData: time, voltage
%   pHCalData: time, voltage, temperature, NaOH volume (zero when no titration)
if size(tempCalData,2)==6 % if it is a calibration with NaOH titration
    if CalData1Type==1 % if the first data block is Ca voltage
        CaCalData = [CalDataBlock1{:,1} CalDataBlock1{:,2}];
        pHCalData = [CalDataBlock2{:,1} CalDataBlock2{:,2} ...
            str2double(CalDataBlock2{:,5}) CalDataBlock2{:,3}];
    else
        CaCalData = [CalDataBlock2{:,1} CalDataBlock2{:,2}];
        if isstring(CalDataBlock1{1,5}) % Sometimes T is read in as a string
            pHCalData = [CalDataBlock1{:,1} CalDataBlock1{:,2} ...
                str2double(CalDataBlock1{:,5}) CalDataBlock1{:,3}];
        else
            pHCalData = [CalDataBlock1{:,1} CalDataBlock1{:,2} ...
                CalDataBlock1{:,5} CalDataBlock1{:,3}];
        end
    end
else % if it is without NaOH titration
    if CalData1Type==1 % if the first data block is Ca voltage
        CaCalData = [CalDataBlock1{:,1} CalDataBlock1{:,2}];
        pHCalData = [CalDataBlock2{:,1} CalDataBlock2{:,2} ...
            CalDataBlock2{:,4} zeros(height(CalDataBlock2),1)];
    else
        CaCalData = [CalDataBlock2{:,1} CalDataBlock2{:,2}];
        pHCalData = [CalDataBlock1{:,1} CalDataBlock1{:,2} ...
            CalDataBlock1{:,4} zeros(height(CalDataBlock1),1)];
    end
end
% Interpolate Ca Data to the times given in the pH data file
% Time is taken from pH data from this point forward
CaCalData = interp1(CaCalData(:,1),CaCalData(:,2),pHCalData(:,1));

% Extract desired portions of data from the calibration
% Calibration data format: 1) time, 2) pH, 3) temperature, 4) NaOH vol., 5)
% Ca voltage, 5) Ca conc. (mM)
% Find nearest calibration data point
tempLoc = [abs(pHCalData(:,1)-metaData.t0(i)) (1:1:size(pHCalData,1))'];
tempLoc = sortrows(tempLoc,1);
calData(1,:) = [mean(pHCalData(tempLoc(1,2)-20:tempLoc(1,2),:),'omitnan') ...
    mean(CaCalData(tempLoc(1,2)-20:tempLoc(1,2),1),'omitnan')];
% 2nd calibration data point
tempLoc = [abs(pHCalData(:,1)-metaData.t1(i)) (1:1:size(pHCalData,1))'];
tempLoc = sortrows(tempLoc,1);
calData(2,:) = [mean(pHCalData(tempLoc(1,2)-20:tempLoc(1,2),:),'omitnan') ...
    mean(CaCalData(tempLoc(1,2)-20:tempLoc(1,2),1),'omitnan')];
% 3rd calibration data point
tempLoc = [abs(pHCalData(:,1)-metaData.t2(i)) (1:1:size(pHCalData,1))'];
tempLoc = sortrows(tempLoc,1);
calData(3,:) = [mean(pHCalData(tempLoc(1,2)-20:tempLoc(1,2),:),'omitnan') ...
    mean(CaCalData(tempLoc(1,2)-20:tempLoc(1,2),1),'omitnan')];
% 4th calibration data point
tempLoc = [abs(pHCalData(:,1)-metaData.t3(i)) (1:1:size(pHCalData,1))'];
tempLoc = sortrows(tempLoc,1);
calData(4,:) = [mean(pHCalData(tempLoc(1,2)-20:tempLoc(1,2),:),'omitnan') ...
    mean(CaCalData(tempLoc(1,2)-20:tempLoc(1,2),1),'omitnan')];
% 5th calibration data point (if it exists)
if metaData.t4(i)==-999
    calData(5,:) = NaN;
    % Add Ca conc. from metadatafile
    calData(:,6) = [metaData.calconc1(i) ; metaData.calconc2(i) ; ...
        metaData.calconc3(i) ; metaData.calconc4(i) ; NaN];
else
    tempLoc = [abs(pHCalData(:,1)-metaData.t4(i)) (1:1:size(pHCalData,1))'];
    tempLoc = sortrows(tempLoc,1);
    calData(5,:) = [mean(pHCalData(tempLoc(1,2)-20:tempLoc(1,2),:),'omitnan') ...
        mean(CaCalData(tempLoc(1,2)-20:tempLoc(1,2),1),'omitnan')];% Add Ca conc. from metadatafile
    calData(:,6) = [metaData.calconc1(i) ; metaData.calconc2(i) ; ...
        metaData.calconc3(i) ; metaData.calconc4(i) ; metaData.calconc5(i)];
end
calData(isnan(calData(:,1)),:) = [];

% Calculate Ca activity for all calibration data points
calVol = 200; % Volume of the calibration; always 200 ml in our experiments
for j = 1:size(calData,1)
    if ~isnan(calData(j,1))

        % dilution due to NaOH titration
        dilutionFac = calVol/(calVol + calData(j,4));
    
        IPCstringCell= {'SOLUTION 1',  ...
            ['-temp ', num2str(calData(j,3))],  ...
            ['-pH ', num2str(calData(j,2))],  ...
            '-units mmol/L',  ...
            '-density 1.025',  ...
            ['Ca ', num2str(calData(j,6)*dilutionFac)],  ...           
            ['Na ', num2str(metaData.Naconc(i)*dilutionFac)],  ...
            ['Cl ', num2str(metaData.Naconc(i)*dilutionFac + calData(j,6)*dilutionFac*2)],  ...
        'SELECTED_OUTPUT',  ...
            '-molalities  CO3-2  HCO3-  Ca+2 ', ...
            '-activities  CO3-2  HCO3-  Ca+2 ', ...
            'soln false',  ...
            'pH true',  ...
            'sim false',  ...
            'state false',  ...
            'time false',  ...
            'step false',  ...
            'pe false',  ...
            'distance false'};
        IPCstring = sprintf('%s\n', IPCstringCell{:});
    
        iphreeqc.RunString( IPCstring );
        OUTphreeqSTRING = iphreeqc.GetSelectedOutputArray;
    
        locCa = find(strcmp(OUTphreeqSTRING,'la_Ca+2'));
        calData(j,7) = 10^OUTphreeqSTRING{2,(locCa+1)/2}.*1000;
    end
end

% Calculate the relationship between activity and voltage
modelfun = @(b,x) b(1)+b(2).*log(x);
beta0 = [0.5 10];
% Exclude blank-sensitive concentration for now
yTemp = calData(calData(:,6)>0.05,5);
xTemp = calData(calData(:,6)>0.05,7);
mdlCal = fitnlm(xTemp,yTemp,modelfun,beta0); 

if min(calData(:,6))<=0.05 % If a low concentration calibration datapoint is available
    % Calculate the offset between calibration line and lowest calibration data
    % point (Ca blank)
    % expected activity for measured voltage
    expAc = exp((calData(1,5) - table2array(mdlCal.Coefficients(1,1)))/...
        table2array(mdlCal.Coefficients(2,1)));
    % Determine the conc. from this activity by trial and error
    a = 0;
    tempAc = 0.001;
    trialConc = 0.001;
    while abs(tempAc - expAc)/expAc > 0.005
        a = a + 1; % Only for troubleshooting

        trialConc = trialConc*expAc/tempAc;
    
        IPCstringCell= {'SOLUTION 1',  ...
            ['-temp ', num2str(calData(j,3))],  ...
            ['-pH ', num2str(calData(j,2))],  ...
            '-units mmol/L',  ...
            '-density 1.025',  ...
            ['Ca ', num2str(trialConc)],  ...           
            ['Na ', num2str(metaData.Naconc(i)*dilutionFac)],  ...
            ['Cl ', num2str(metaData.Naconc(i)*dilutionFac + calData(j,6)*dilutionFac*2)],  ...
        'SELECTED_OUTPUT',  ...
            '-molalities  CO3-2  HCO3-  Ca+2 ', ...
            '-activities  CO3-2  HCO3-  Ca+2 ', ...
            'soln false',  ...
            'pH true',  ...
            'sim false',  ...
            'state false',  ...
            'time false',  ...
            'step false',  ...
            'pe false',  ...
            'distance false'};
        IPCstring = sprintf('%s\n', IPCstringCell{:});
    
        iphreeqc.RunString( IPCstring );
        OUTphreeqSTRING = iphreeqc.GetSelectedOutputArray;
    
        locCa = find(strcmp(OUTphreeqSTRING,'la_Ca+2'));
        tempAc = 10^OUTphreeqSTRING{2,(locCa+1)/2}.*1000;

    end
    CaBlank = trialConc - calData(1,6);
    clear tempAc trialConc a
    
    % recalculate activities with Ca blank added to all input concentrations
    % column 8 of calData = new concentrations
    % column 9 of calData = recalculated activities
    calData(:,8) = calData(:,6) + CaBlank;
    for j = 1:size(calData,1)
        if ~isnan(calData(j,1))
    
            % dilution due to NaOH titration
            dilutionFac = calVol/(calVol + calData(j,4));
            IPCstringCell= {'SOLUTION 1',  ...
                ['-temp ', num2str(calData(j,3))],  ...
                ['-pH ', num2str(calData(j,2))],  ...
                '-units mmol/L',  ...
                '-density 1.025',  ...
                ['Ca ', num2str(calData(j,8))],  ...           
                ['Na ', num2str(metaData.Naconc(i)*dilutionFac)],  ...
                ['Cl ', num2str(metaData.Naconc(i)*dilutionFac + calData(j,8)*dilutionFac*2)],  ...
             'SELECTED_OUTPUT',  ...
                '-molalities  CO3-2  HCO3-  Ca+2 ', ...
                '-activities  CO3-2  HCO3-  Ca+2 ', ...
                'soln false',  ...
                'pH true',  ...
                'sim false',  ...
                'state false',  ...
                'time false',  ...
                'step false',  ...
                'pe false',  ...
                'distance false'};
            IPCstring = sprintf('%s\n', IPCstringCell{:});
        
            iphreeqc.RunString( IPCstring );
            OUTphreeqSTRING = iphreeqc.GetSelectedOutputArray;
        
            locCa = find(strcmp(OUTphreeqSTRING,'la_Ca+2'));
            calData(j,9) = 10^OUTphreeqSTRING{2,(locCa+1)/2}.*1000;
        end
    end
    
    % Recalculate calibration using blank-corrected data
    mdlCalBlank = fitnlm(calData(:,9),calData(:,5),modelfun,beta0);
else
    calData(:,9) = NaN;
    mdlCalBlank = mdlCal;
end

% Plot calibration
cmap = parula(12);
close(figure(1))
H = figure(1);
set(H,'PaperUnits','centimeter','units','centimeter',...
    'papersize',[12 10],'Position',[20 10 12 10],'color',[1 1 1])
hold on
scatter(calData(:,7),calData(:,5),30,cmap(1,:),'filled',...
    'markeredgecolor','k','linewidth',0.5);
scatter(calData(:,9),calData(:,5),30,cmap(5,:),'filled',...
    'markeredgecolor','k','linewidth',0.5);
plot((0.001:0.001:20),...
    mdlCal.Coefficients{1,1}+mdlCal.Coefficients{2,1}.*...
    log((0.001:0.001:20)),'-','color',cmap(3,:))
plot((0.001:0.001:20),...
    mdlCalBlank.Coefficients{1,1}+mdlCalBlank.Coefficients{2,1}.*...
    log((0.001:0.001:20)),'-','color',cmap(6,:))

set(gca,'xscale','log','fontsize',8)
legend('without blank correction','with blank correction',...
    'location','northwest','box','off')
set(gcf,'color','w')
xlabel('\alpha_{Ca^{2+}} \times10^3')
ylabel('Ca electrode (mV)')
set(gca,'box','on')

print(H,'-dpng','-r600',...
    [metaData.experiment{i} ('_') num2str(i) ('_calibration_')])
close(figure(1))



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Read in and process titration data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Read in titration data
dirF2 = 'C:\Users\evans\Data\Earth_Science\co-author\Anthea\titratio_processing_revised_script\titration-files';
FileName2 = [metaData.experiment{i} '.csv'];
      
tempFN = [dirF2 '\' FileName2];
%%% TEMP
% copy to new folder
saveDirCal = 'C:\Users\evans\Data\Earth_Science\co-author\Anthea\titratio_processing_revised_script\Arns_et_al_2026_Matlab_titration_data_processing\titration_data';
copyfile(tempFN,saveDirCal)
tempTitData = readtable(tempFN,'VariableNamingRule','preserve');

fid = fopen(tempFN);
fgets(fid); % Scroll down to the determiner
fgets(fid);
fgets(fid);
fline = fgets(fid);
TitData1Type = strcmp('MEAS U',fline(1:6)); % 1 if Ca first, 0 if pH first

% Find location of other data blocks
TitDataLoc = [isnan(tempTitData{:,1}) (1:1:size(tempTitData,1))'];
TitDataLoc = TitDataLoc(TitDataLoc(:,1)==1,2);

% Sort data blocks into continuous Ca and pH data files
% pH data file format: 1) time, 2) pH, 3) temperature, 4) NaOH vol.

% The Tiamo method was updated several times
% over the course of the experiments reported here, such that several
% formats of the raw csv files are present, dealt with by the block of code
% below.

% If there are four data blocks in total, there are three dividers x2
if size(TitDataLoc,1)==6
    TitDataBlock1 = tempTitData(1:TitDataLoc(1,1)-1,:);
    TitDataBlock2 = tempTitData(TitDataLoc(2,1)+1:TitDataLoc(3,1)-1,:);
    TitDataBlock3 = tempTitData(TitDataLoc(4,1)+1:TitDataLoc(5,1)-1,:);
    TitDataBlock4 = tempTitData(TitDataLoc(6,1)+1:height(tempTitData),:);
    if TitData1Type==1 % If Ca monitoring started before pH monitoring
        CaTitData = [TitDataBlock1{:,1} TitDataBlock1{:,2}];
    else
        CaTitData = [TitDataBlock2{:,1} TitDataBlock2{:,2}];
    end
    pHTitData = [TitDataBlock4{:,1} TitDataBlock4{:,2} ...
            str2double(TitDataBlock4{:,5}) TitDataBlock4{:,3}];
elseif size(TitDataLoc,1)==4
    % If there are three (pH monitoring followed by pH stat)
    TitDataBlock1 = tempTitData(1:TitDataLoc(1,1)-1,:);
    TitDataBlock2 = tempTitData(TitDataLoc(2,1)+1:TitDataLoc(3,1)-1,:);
    TitDataBlock3 = tempTitData(TitDataLoc(4,1)+1:height(tempTitData),:);
    if TitData1Type==1 % If Ca monitoring started before pH monitoring
        CaTitData = [TitDataBlock1{:,1} TitDataBlock1{:,2}];
    else
        CaTitData = [TitDataBlock2{:,1} TitDataBlock2{:,2}];
    end
    pHTitData = [TitDataBlock3{:,1} TitDataBlock3{:,2} ...
        str2double(TitDataBlock3{:,5}) TitDataBlock3{:,3}];
else 
    % If there are fewer (solubility experiments)
    TitDataBlock1 = tempTitData(1:TitDataLoc(1,1)-1,:);
    TitDataBlock2 = tempTitData(TitDataLoc(2,1)+1:height(tempTitData),:);
    if TitData1Type==1 % If Ca monitoring started before pH monitoring
        CaTitData = [TitDataBlock1{:,1} TitDataBlock1{:,2}];
        % This if command here and below the next 'else' is necessary as
        % there is otherwise confusion between solubility files produced in
        % Frankfurt and titration experiments performed in Southampton
        if strfind(metaData.experiment{i,1},'sol')~=0
            pHTitData = [TitDataBlock2{:,1} TitDataBlock2{:,2} ...
                TitDataBlock2{:,4} zeros(height(TitDataBlock2),1)];
        else
            % Sometimes temperature data is read in as a string (also
            % below)
            if isnumeric(TitDataBlock1{1,5})==1
                pHTitData = [TitDataBlock2{:,1} TitDataBlock2{:,2} ...
                    TitDataBlock2{:,5} TitDataBlock2{:,3}];
            else
                pHTitData = [TitDataBlock2{:,1} TitDataBlock2{:,2} ...
                    str2double(TitDataBlock2{:,5}) TitDataBlock2{:,3}];
            end
        end
    else
        CaTitData = [TitDataBlock2{:,1} TitDataBlock2{:,2}];
        if ~isempty(strfind(metaData.experiment{i,1},'sol'))
            pHTitData = [TitDataBlock1{:,1} TitDataBlock1{:,2} ...
                TitDataBlock1{:,4} zeros(height(TitDataBlock1),1)];
        else
            if isnumeric(TitDataBlock1{1,5})==1
                pHTitData = [TitDataBlock1{:,1} TitDataBlock1{:,2} ...
                    TitDataBlock1{:,5} TitDataBlock1{:,3}];
            else           
                pHTitData = [TitDataBlock1{:,1} TitDataBlock1{:,2} ...
                    str2double(TitDataBlock1{:,5}) TitDataBlock1{:,3}];
            end
        end
    end
end
% Throw away the portion of the Ca dataset collected before solution
% adjustments were made:
% If there was less than half an hour of adjustment, delete irrelevant
% portion of Ca dataset
if abs(size(CaTitData,1) - size(pHTitData,1))<1800
    CaTitData(1:(size(CaTitData,1) - size(pHTitData,1)),:) = [];
else
    % Else assume that data frequency differs, and interpolate pH data to
    % that of Ca
    pHTitData = [CaTitData(:,1) ...
        interp1(pHTitData(:,1),...
        pHTitData(:,2:size(pHTitData,2)),CaTitData(:,1))];
end

% Read relevant meta data
solComp = [metaData.Ca(i) metaData.Mg(i) ...
    metaData.sw_DIC(i)/1000 metaData.init_cDIC(i)/1000];
solComp(isnan(solComp)) = 0;
volIn = metaData.V_ml(i);
rate = metaData.dr_mlmin(i);
dosingConc = [metaData.titrant_concCa(i) metaData.titrant_concMg(i)].*1000;
maxVol = metaData.V_titrated(i);

% Find row number of onset of titration
xLoc = [abs(CaTitData(:,1) - metaData.t_titration_start(i)) ...
    (1:1:size(CaTitData,1))'];
xLoc = sortrows(xLoc,1);
xLoc = xLoc(1,2);
% Process every nth datapoint from files for efficiency
loopStep = round(size(CaTitData,1)/1000,0)+1; % previously 400

% Was DIC measured at the end of the experiment?
if isnan(metaData.DIC_meas(i))
    haveDIC = 0;
else
    haveDIC = metaData.DIC_recalc(i); % or DIC_meas if running on the first pass
end
if haveDIC>0
    % use NaOH titration curve to create a synthetic DIC curve assuming
    % 1 M NaOH titration = 1 M DIC CO2 diffusion (broad approx.). 0.1
    % is the NaOH concentration of the dosing solution. Units in mmol.        
    syntFinDIC = ...
        (pHTitData(:,4) - max(pHTitData(:,4))).*0.5.*0.1/1000*(1000/volIn)*1000;
    % Only apply this after titration has stopped (before this, NaOH
    % also reflects precipitation and CaCl2 titration)
    syntFinDIC(pHTitData(:,1)<xLoc + maxVol/rate*60,:) = 0;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% phreeqc calculations start here
co2sysOut = NaN(round(size(pHTitData,1)/loopStep,0),81);
volTot = ones(round(size(pHTitData,1)/loopStep,0),1).*volIn;
acCa = NaN(round(size(pHTitData,1)/loopStep,0),6);
DICcalc = NaN(round(size(pHTitData,1)/loopStep,0),2);
totalCa = NaN(round(size(pHTitData,1)/loopStep,0),1);
MgCaConc = NaN(round(size(pHTitData,1)/loopStep,0),3);
iphreeqcC = parallel.pool.Constant(iphreeqc);
%f = waitbar(0/size(pHTitData,1),'solution calculation running...');  
clear revDIC T50 tempDICjumpLoc

parfor j = 1:round(size(pHTitData,1)/loopStep,0)-1    % solve PHREEQC for every titration datapoint   
    iphreeqc = actxserver('IPhreeqcCOM.Object');    % create PHREEQC COM object
    iphreeqc.LoadDatabase([dirP dbStr]);
    %iphreeqcC.Value.LoadDatabase([dirP dbStr]);
    %waitbar(i/size(pHTitData,1),f)

    if CaTitData(loopStep*j)>CaTitData(xLoc,1) % start data processing at point of titration
        if (CaTitData(loopStep*j,1)-CaTitData(xLoc,1))*rate/60 > maxVol &&...
                maxVol>0
            vol = volIn + maxVol + pHTitData(loopStep*j,4);
        else
            vol = volIn + (CaTitData(loopStep*j,1)-CaTitData(xLoc,1))/60*rate + ...
                pHTitData(loopStep*j,4);
        end
        volTot(j,1) = vol;
        tempCalCa = exp((CaTitData(loopStep*j,2)-mdlCalBlank.Coefficients{1,1})./... % electrode calibrated acCa 
            mdlCalBlank.Coefficients{2,1});
        
        deltaAc = NaN(10,1);    % empty matrix for iterative loop
        deltaAc(1) = 1;
        deltaAc(2) = 1;
        a = 2;
        missCa = 1;
        tempDIC = 1;
        % Iteratively solve for Ca and DIC assuming missing Ca = missing
        % DIC
        while abs(deltaAc(a))>0.001 && tempDIC>0.5
            a = a+1;

            tempDIC = solComp(1,4)*volIn/vol;
            % if titration stopped part way through experiment
            if (CaTitData(loopStep*j,1)-CaTitData(xLoc,1))*rate/60 > maxVol &&...
                    maxVol>0
                tempCa = solComp(1,1) + maxVol*...
                    dosingConc(1)/1000*1000/vol*volIn/vol;
                tempMg = solComp(1,2) + maxVol*...
                    dosingConc(2)/1000*1000/vol*volIn/vol; 
            else % if titration has not stopped yet, or was never stopped
                tempCa = solComp(1,1) + (CaTitData(loopStep*j,1)-CaTitData(xLoc,1))*...
                    dosingConc(1)/1000*rate*1/60*1000/vol*volIn/vol;
                tempMg = solComp(1,2) + (CaTitData(loopStep*j,1)-CaTitData(xLoc,1))*...
                    dosingConc(2)/1000*rate*1/60*1000/vol*volIn/vol; 
            end
            tempNa = metaData.Na(i)*volIn/vol;
            tempCl = (metaData.Cl(i)+2*tempCa)*volIn/vol;
            tempCaIn = tempCa;
            if a>3
                tempDIC = tempDIC - tempCa*(1-missCa);
            end
            tempCa = tempCa*missCa;
            % Record total titrated [Ca]
            if a==3
                totalCa(j,:) = tempCa;
            end
    
            % Calculate TAlk from pH and DIC, as pH experiment pH
            % calibration is on the NBS scale, but unsure of phreeqc pH
            % scale
            % Adjust K1, K2 for Ca, Mg, SO4
            tSO4 = metaData.S_6_(i)*volIn/vol;
            tCa = tempCa;
            tMg = tempMg;
            K1rat = 1 + 5/1000.*(tCa./10.3-1) + 17/1000.*(tMg./53-1) + ...
                208./1000.*(tSO4./(290.46/10.3)-1);
            K2rat = 1 + 157/1000.*(tCa./10.3-1) + 420/1000.*(tMg./53-1) + ...
                176./1000.*(tSO4/(290.46/10.3)-1);

            co2sysOutTemp = CO2SYSpalaeo(tempDIC*1000,pHTitData(loopStep*j,2),2,3,35,...
                pHTitData(loopStep*j,3),pHTitData(loopStep*j,3),0,0,0,0,4,4,1,K1rat,K2rat);

            IPCstringCell= {'SOLUTION 1',  ...
                ['-temp ', num2str(pHTitData(loopStep*j,3))],  ...
                '-units mmol/L',  ...
                ['-density ', num2str(metaData.density(i))],  ...
                ['Ca ', num2str(tempCa)],  ...
                ['Mg ', num2str(tempMg)], ...
                ['Na ', num2str(tempNa)],  ...
                ['K ', num2str(metaData.K(i)*volIn/vol)],  ...
                ['Cl ', num2str(tempCl)],  ...
                ['S(6) ', num2str(metaData.S_6_(i)*volIn/vol)],  ...
                ['C(4) ', num2str(tempDIC)],  ...
                ['B ', num2str(metaData.B_OH_3(i)*volIn/vol)],  ...
                ['Br ', num2str(metaData.Br(i)*volIn/vol)],  ...
                ['Sr ', num2str(metaData.Sr(i)*volIn/vol)],  ...
                ['pH ', num2str(pHTitData(loopStep*j,2))],  ...
            'SELECTED_OUTPUT',  ...
                '-molalities  CO3-2  HCO3-  Ca+2 ', ...
                '-activities  CO3-2  HCO3-  Ca+2 Mg+2', ...
                'soln false',  ...
                'pH true',  ...
                'sim false',  ...
                'state false',  ...
                'time false',  ...
                'step false',  ...
                'pe false',  ...
                'distance false'};
            IPCstring = sprintf('%s\n', IPCstringCell{:});
    
            iphreeqc.RunString( IPCstring );
            OUTphreeqSTRING = iphreeqc.GetSelectedOutputArray;

            % If running as a for loop
            %iphreeqc.RunString( IPCstring );
            %OUTphreeqSTRING = iphreeqc.GetSelectedOutputArray;
    
            locCa = find(strcmp(OUTphreeqSTRING,'la_Ca+2'));
            locCO3 = find(strcmp(OUTphreeqSTRING,'la_CO3-2'));
            locMg = find(strcmp(OUTphreeqSTRING,'la_Mg+2'));
            tempMgAc = 10^OUTphreeqSTRING{2,(locMg+1)/2};
            if a<4
                acCaTemp = [10^OUTphreeqSTRING{2,(locCa+1)/2} ...
                    10^OUTphreeqSTRING{2,(locCO3+1)/2} ...
                    10^OUTphreeqSTRING{2,(locCa+1)/2} ...
                    10^OUTphreeqSTRING{2,(locCO3+1)/2} NaN NaN];
                tempCaOff = acCaTemp(1,1)*1000 - tempCalCa;
            else
                acCaTemp = [acCaTemp(1,1:2) ...
                    10^OUTphreeqSTRING{2,(locCa+1)/2} ...
                    10^OUTphreeqSTRING{2,(locCO3+1)/2} NaN NaN];
                
                tempCaOff = acCaTemp(1,3)*1000 - tempCalCa;
            end                   
            deltaAc(a) = tempCaOff;
            missCa = missCa.*tempCalCa/(acCaTemp(1,3)*1000);
        end
        DICcalc(j,:) = [tempDIC NaN];
        MgCaConc(j,:) = [tempCa tempMg tempMgAc];
    
    
        % Do it again using the iterative solution, but only allow
        % DIC to fall to the final known concentration minus the
        % DIC derived from CO2 diffusion after titration stopped,
        % then trend back towards measured DIC using the
        % NaOH-derived curve
    
        if haveDIC>0
            deltaAc = NaN(10,1);    % empty matrix for iterative loop
            deltaAc(1) = 1;
            deltaAc(2) = 1;
            a = 2;
            missCa = 1;
            while abs(deltaAc(a))>0.001 && tempDIC>0.5
                a = a+1;
                tempDIC = solComp(1,4)*volIn/vol;
                % if titration stopped part way through experiment
                if (CaTitData(loopStep*j,1)-CaTitData(xLoc,1))*rate/60 > maxVol &&...
                        maxVol>0
                    tempCa = solComp(1,1) + maxVol*...
                        dosingConc(1)/1000*1000/vol;
                    tempMg = solComp(1,2) + maxVol*...
                        dosingConc(2)/1000*1000/vol; 
                else % if titration has not stopped yet, or was never stopped
                    tempCa = solComp(1,1) + (CaTitData(loopStep*j,1)-CaTitData(xLoc,1))*...
                        dosingConc(1)/1000*rate*1/60*1000/vol;
                    tempMg = solComp(1,2) + (CaTitData(loopStep*j,1)-CaTitData(xLoc,1))*...
                        dosingConc(2)/1000*rate*1/60*1000/vol; 
                end
                tempNa = metaData.Na(i)*volIn/vol;
                tempCl = (metaData.Cl(i)+2*tempCa)*volIn/vol;
              
                tempDIC = tempDIC - tempCa*(1-missCa);
                tempCa = tempCa*missCa;   

                % adjust DIC using measured value and NaOH curve if
                % calculated DIC drops to that point
                if tempDIC + min(syntFinDIC)<haveDIC/1000 && maxVol>0
                    if CaTitData(loopStep*j,1) >= xLoc + maxVol/rate*60
                        tempDIC = haveDIC/1000 + syntFinDIC(loopStep*j,1);
                    end                            
                end
                % Adjust K1, K2 for Ca, Mg, SO4
                tSO4 = metaData.S_6_(i)*volIn/vol;
                tCa = tempCa;
                tMg = tempMg;
                K1rat = 1 + 5/1000.*(tCa./10.3-1) + 17/1000.*(tMg./53-1) + ...
                    208./1000.*(tSO4./(290.46/10.3)-1);
                K2rat = 1 + 157/1000.*(tCa./10.3-1) + 420/1000.*(tMg./53-1) + ...
                    176./1000.*(tSO4/(290.46/10.3)-1);
                co2sysOutTemp = CO2SYSpalaeo(tempDIC*1000,pHTitData(loopStep*j,2),2,3,35,...
                    pHTitData(loopStep*j,3),pHTitData(loopStep*j,3),0,0,0,0,4,4,1,K1rat,K2rat);

                IPCstringCell= {'SOLUTION 1',  ...
                    ['-temp ', num2str(pHTitData(loopStep*j,3))],  ...
                    '-units mmol/L',  ...
                    ['-density ', num2str(metaData.density(i))],  ...
                    ['Ca ', num2str(tempCa)],  ...
                    ['Mg ', num2str(tempMg)], ...
                    ['Na ', num2str(tempNa)],  ...
                    ['K ', num2str(metaData.K(i)*volIn/vol)],  ...
                    ['Cl ', num2str(tempCl)],  ...
                    ['S(6) ', num2str(metaData.S_6_(i)*volIn/vol)],  ...
                    ['C(4) ', num2str(tempDIC)],  ...
                    ['B ', num2str(metaData.B_OH_3(i)*volIn/vol)],  ...
                    ['Br ', num2str(metaData.Br(i)*volIn/vol)],  ...
                    ['Sr ', num2str(metaData.Sr(i)*volIn/vol)],  ...
                    ['pH ', num2str(pHTitData(loopStep*j,2))],  ...                
                'SELECTED_OUTPUT',  ...
                    '-molalities  CO3-2  HCO3-  Ca+2 ', ...
                    '-activities  CO3-2  HCO3-  Ca+2 ', ...
                    'soln false',  ...
                    'pH true',  ...
                    'sim false',  ...
                    'state false',  ...
                    'time false',  ...
                    'step false',  ...
                    'pe false',  ...
                    'distance false'};
                IPCstring = sprintf('%s\n', IPCstringCell{:});

                iphreeqc.RunString( IPCstring );
                OUTphreeqSTRING = iphreeqc.GetSelectedOutputArray;

                locCa = find(strcmp(OUTphreeqSTRING,'la_Ca+2'));
                locCO3 = find(strcmp(OUTphreeqSTRING,'la_CO3-2'));
                if a>2
                    % temp acCa needed to accommodate parfor
                    acCaTemp = [acCaTemp(1,1:4) 10^OUTphreeqSTRING{2,(locCa+1)/2} ...
                        10^OUTphreeqSTRING{2,(locCO3+1)/2}];
                    tempCaOff = acCaTemp(1,5)*1000 - tempCalCa;
                end                                        
                deltaAc(a) = tempCaOff;
                missCa = missCa.*tempCalCa/(acCaTemp(1,5)*1000);
            end
        end
    
        % The above DIC correction does not
        % accurately find the point at which the measured (+NaOH)
        % DIC should take over because it is an iterative solution,
        % resulting in measured taking over too soon. This puts
        % back the iterative solution in these cases.
        if maxVol>0
            if acCaTemp(1,6)<acCaTemp(1,4) && CaTitData(loopStep*j,1) < xLoc + maxVol/rate*60                    
                acCaTemp = [acCaTemp(1,1:5) acCaTemp(1,4)];
            end
        end
    
        acCa(j,:) = acCaTemp;
        co2sysOut(j,:) = co2sysOutTemp;
    end
end
%close(f)


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Repeat the calculation using a composite DIC curve based on the
% iterative solution above matched to the final measured value where
% they overlap
acCa2 = NaN(size(acCa,1),2);
if haveDIC>0
    % Stretched DIC evolution curve to fit both iterative solution and measured
    % final value including NaOH titration after Ca titration stopped:

    %adjust DIC using the measured value and NaOH curve if
    %calculated DIC drops below that point
    DICfi = co2sysOut(:,2);

    % Where the switch to the inclusion of a CO2 diffusion contribution to
    % DIC occurs
    tempDICjumpLoc = [abs(DICfi-min(DICfi(50:size(DICfi,1),:))) ...
        (1:1:size(DICfi,1))'];
    tempDICjumpLoc = sortrows(tempDICjumpLoc,1);
    tempDICjumpLoc = tempDICjumpLoc(1,2);
    
    % The DIC curve is then rescaled to avoid a jump between the iterative
    % solution above and the inclusion of the diffusion component here
    maxDIC = max(DICfi);
    minDIC = DICfi(tempDICjumpLoc-1);
    targetMinDIC = DICfi(tempDICjumpLoc);
    DICfi = DICfi.*(maxDIC - targetMinDIC)/(maxDIC - minDIC);
    DICfi = DICfi + maxDIC - max(DICfi);
    DICfi(tempDICjumpLoc:size(DICfi,1),:) = ...
        co2sysOut(tempDICjumpLoc:size(DICfi,1),2);
    
    %f = waitbar(0/size(pHTitData,1),'solution calculation running...');         
    parfor j = 1:round(size(pHTitData,1)/loopStep,0)-1    % solve PHREEQC for every titration datapoint
        iphreeqc = actxserver('IPhreeqcCOM.Object');    % create PHREEQC COM object
        iphreeqc.LoadDatabase([dirP dbStr]);
        %iphreeqcC.Value.LoadDatabase([dirP dbStr]);
            %waitbar(i/size(pHTitData,1),f)
        
        tempMg = 0;
    
        % no need to perform the calculation for the earlier parts of the
        % experiment:
        if CaTitData(loopStep*j)>CaTitData(xLoc,1)

            if (CaTitData(loopStep*j,1)-CaTitData(xLoc,1))*rate/60 > maxVol &&...
                maxVol>0
                vol = volIn + maxVol + pHTitData(loopStep*j,4);
            else
                vol = volIn + (CaTitData(loopStep*j,1)-CaTitData(xLoc,1))/60*rate + ...
                    pHTitData(loopStep*j,4);
            end
            tempCalCa = exp((CaTitData(loopStep*j,2)-mdlCalBlank.Coefficients{1,1})./... % electrode calibrated acCa 
                mdlCalBlank.Coefficients{2,1});
            
            deltaAc = NaN(10,1);    % empty matrix for iterative loop
            deltaAc(1) = 1;
            deltaAc(2) = 1;
            a = 2;
            missCa = 1;
            tempDIC = 1;
            acCaTemp = acCa(j,:);
            acCaTemp = acCaTemp(1,5:6);
            while abs(deltaAc(a))>0.001 && tempDIC>0.5
                a = a+1;
                tempDIC = DICfi(j)/1000;
                % if titration stopped part way through experiment
                if (CaTitData(loopStep*j,1)-CaTitData(xLoc,1))*rate/60 > maxVol &&...
                        maxVol>0
                    tempCa = solComp(1,1) + maxVol*...
                        dosingConc(1)/1000*1000/vol;
                    tempMg = solComp(1,2) + maxVol*...
                        dosingConc(2)/1000*1000/vol; 
                else % if titration has not stopped yet, or was never stopped
                    tempCa = solComp(1,1) + (CaTitData(loopStep*j,1)-CaTitData(xLoc,1))*...
                        dosingConc(1)/1000*rate*1/60*1000/vol;
                    tempMg = solComp(1,2) + (CaTitData(loopStep*j,1)-CaTitData(xLoc,1))*...
                        dosingConc(2)/1000*rate*1/60*1000/vol; 
                end
                tempNa = metaData.Na(i)*volIn/vol;
                tempCl = (metaData.Cl(i)+2*tempCa)*volIn/vol;
    
                tempCa = tempCa*missCa;                   
                
                % Adjust K1, K2 for Ca, Mg, SO4
                tSO4 = metaData.S_6_(i)*volIn/vol;
                tCa = tempCa;
                tMg = tempMg;
                K1rat = 1 + 5/1000.*(tCa./10.3-1) + 17/1000.*(tMg./53-1) + ...
                    208./1000.*(tSO4./(290.46/10.3)-1);
                K2rat = 1 + 157/1000.*(tCa./10.3-1) + 420/1000.*(tMg./53-1) + ...
                    176./1000.*(tSO4/(290.46/10.3)-1);
                co2sysOutTemp = CO2SYSpalaeo(tempDIC*1000,pHTitData(loopStep*j,2),2,3,35,...
                    pHTitData(loopStep*j,3),pHTitData(loopStep*j,3),0,0,0,0,4,4,1,K1rat,K2rat);
    
                IPCstringCell= {'SOLUTION 1',  ...
                    ['-temp ', num2str(pHTitData(loopStep*j,3))],  ...
                    '-units mmol/L',  ...
                    ['-density ', num2str(metaData.density(i))],  ...
                    ['Ca ', num2str(tempCa)],  ...
                    ['Mg ', num2str(tempMg)], ...
                    ['Na ', num2str(tempNa)],  ...
                    ['K ', num2str(metaData.K(i)*volIn/vol)],  ...
                    ['Cl ', num2str(tempCl)],  ...
                    ['S(6) ', num2str(metaData.S_6_(i)*volIn/vol)],  ...
                    ['C(4) ', num2str(tempDIC)],  ...
                    ['B ', num2str(metaData.B_OH_3(i)*volIn/vol)],  ...
                    ['Br ', num2str(metaData.Br(i)*volIn/vol)],  ...
                    ['Sr ', num2str(metaData.Sr(i)*volIn/vol)],  ...
                    ['pH ', num2str(pHTitData(loopStep*j,2))],  ...
                'SELECTED_OUTPUT',  ...
                    '-molalities  CO3-2  HCO3-  Ca+2 ', ...
                    '-activities  CO3-2  HCO3-  Ca+2 ', ...
                    'soln false',  ...
                    'pH true',  ...
                    'sim false',  ...
                    'state false',  ...
                    'time false',  ...
                    'step false',  ...
                    'pe false',  ...
                    'distance false'};
                IPCstring = sprintf('%s\n', IPCstringCell{:});
    
                iphreeqc.RunString( IPCstring );
                OUTphreeqSTRING = iphreeqc.GetSelectedOutputArray;
    
                locCa = find(strcmp(OUTphreeqSTRING,'la_Ca+2'));
                locCO3 = find(strcmp(OUTphreeqSTRING,'la_CO3-2'));
    
                acCaTemp = [10^OUTphreeqSTRING{2,(locCa+1)/2} ...
                    10^OUTphreeqSTRING{2,(locCO3+1)/2}];
                tempCaOff = acCaTemp(1,1)*1000 - tempCalCa;
                
                deltaAc(a) = tempCaOff;
                missCa = missCa.*tempCalCa/(acCaTemp(1,1)*1000);
            end
            acCa2(j,:) = acCaTemp;
        end
    end
    %close(f)
    DICcalc(:,2) = DICfi;

    % replace previously calculated acCa with new version
    acCa(:,5:6) = acCa2;
    clear acCa2

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Repeat the calculation using a composite DIC curve based on NaOH titration
% initial minus NaOH volume * molarity, converted to moles using the
% experiment volume, converted to mmol and ml
DICNaOH = solComp(1,4) - (pHTitData(1:loopStep:size(acCa,1)*loopStep,4).*...
    metaData.conc_NaOH(i)*1000/volIn*metaData.density(i) -...
    pHTitData(xLoc,4).*0.1*1000/volIn*metaData.density(i));

acCaNaOH = NaN(size(acCa,1),3); % 3rd column is [Ca]
parfor j = 1:round(size(pHTitData,1)/loopStep,0)-1    % solve PHREEQC for every titration datapoint
    iphreeqc = actxserver('IPhreeqcCOM.Object');    % create PHREEQC COM object
    iphreeqc.LoadDatabase([dirP dbStr]);
    %iphreeqcC.Value.LoadDatabase([dirP dbStr]);
    %waitbar(i/size(pHTitData,1),f)

    if CaTitData(loopStep*j)>CaTitData(xLoc,1) % start data processing at point of titration
        if (CaTitData(loopStep*j,1)-CaTitData(xLoc,1))*rate/60 > maxVol &&...
                maxVol>0
            vol = volIn + maxVol + pHTitData(loopStep*j,4);
        else
            vol = volIn + (CaTitData(loopStep*j,1)-CaTitData(xLoc,1))/60*rate + ...
                pHTitData(loopStep*j,4);
        end
        volTot(j,1) = vol;

        % if titration stopped part way through experiment
        if (CaTitData(loopStep*j,1)-CaTitData(xLoc,1))*rate/60 > maxVol &&...
                maxVol>0
            tempMg = solComp(1,2) + maxVol*...
                dosingConc(2)/1000*1000/vol; 
            tempCa = solComp(1,1) + maxVol*...
                dosingConc(1)/1000*1000/vol;
        else % if titration has not stopped yet, or was never stopped
            tempMg = solComp(1,2) + (CaTitData(loopStep*j,1)-CaTitData(xLoc,1))*...
                dosingConc(2)/1000*rate*1/60*1000/vol; 
            tempCa = solComp(1,1) + (CaTitData(loopStep*j,1)-CaTitData(xLoc,1))*...
                dosingConc(1)/1000*rate*1/60*1000/vol;
        end
        tempNa = metaData.Na(i)*volIn/vol;
        tempCl = (metaData.Cl(i)+2*tempCa)*volIn/vol;

        % Prevent script from hanging if all DIC is removed from solution
        tempDIC = DICNaOH(j);
        if tempDIC<0.5
            tempDIC = 0.5;
        end
        DDIC = solComp(1,4) - tempDIC;
        tempCa = tempCa - DDIC;                          

        % Calculate TAlk from pH and DIC, as pH experiment pH
        % calibration is on the NBS scale, but unsure of phreeqc pH
        % scale
        % Adjust K1, K2 for Ca, Mg, SO4
        tSO4 = metaData.S_6_(i)*volIn/vol;
        tCa = tempCa;
        tMg = tempMg;
        K1rat = 1 + 5/1000.*(tCa./10.3-1) + 17/1000.*(tMg./53-1) + ...
            208./1000.*(tSO4./(290.46/10.3)-1);
        K2rat = 1 + 157/1000.*(tCa./10.3-1) + 420/1000.*(tMg./53-1) + ...
            176./1000.*(tSO4/(290.46/10.3)-1);
        co2sysOutTemp = CO2SYSpalaeo(tempDIC*1000,pHTitData(loopStep*j,2),2,3,35,...
            pHTitData(loopStep*j,3),pHTitData(loopStep*j,3),0,0,0,0,4,4,1,K1rat,K2rat);

        IPCstringCell= {'SOLUTION 1',  ...
            ['-temp ', num2str(pHTitData(loopStep*j,3))],  ...
            '-units mmol/L',  ...
            ['-density ', num2str(metaData.density(i))],  ...
            ['Ca ', num2str(tempCa)],  ...
            ['Mg ', num2str(tempMg)], ...
            ['Na ', num2str(tempNa)],  ...
            ['K ', num2str(metaData.K(i)*volIn/vol)],  ...
            ['Cl ', num2str(tempCl)],  ...
            ['S(6) ', num2str(metaData.S_6_(i)*volIn/vol)],  ...
            ['C(4) ', num2str(tempDIC)],  ...
            ['B ', num2str(metaData.B_OH_3(i)*volIn/vol)],  ...
            ['Br ', num2str(metaData.Br(i)*volIn/vol)],  ...
            ['Sr ', num2str(metaData.Sr(i)*volIn/vol)],  ...
            ['pH ', num2str(pHTitData(loopStep*j,2))],  ...
        'SELECTED_OUTPUT',  ...
            '-molalities  CO3-2  HCO3-  Ca+2 ', ...
            '-activities  CO3-2  HCO3-  Ca+2 ', ...
            'soln false',  ...
            'pH true',  ...
            'sim false',  ...
            'state false',  ...
            'time false',  ...
            'step false',  ...
            'pe false',  ...
            'distance false'};
        IPCstring = sprintf('%s\n', IPCstringCell{:});

        iphreeqc.RunString( IPCstring );
        OUTphreeqSTRING = iphreeqc.GetSelectedOutputArray;

        % If running as a for loop
        %iphreeqc.RunString( IPCstring );
        %OUTphreeqSTRING = iphreeqc.GetSelectedOutputArray;

        locCa = find(strcmp(OUTphreeqSTRING,'la_Ca+2'));
        locCO3 = find(strcmp(OUTphreeqSTRING,'la_CO3-2'));

        acCaNaOH(j,:) = [10^OUTphreeqSTRING{2,(locCa+1)/2} ...
            10^OUTphreeqSTRING{2,(locCO3+1)/2} tempCa];
    
    end
end
%close(f)

% Calibrated electrode data
calCa = exp((CaTitData(:,2) - mdlCalBlank.Coefficients{1,1})./...
    mdlCalBlank.Coefficients{2,1});

tempAc = [pHTitData(1:loopStep:size(acCa,1)*loopStep,:) ...
    CaTitData(1:loopStep:size(acCa,1)*loopStep,:) acCa ...
    calCa(1:loopStep:size(acCa,1)*loopStep,:)];    % temporary data file with NaNs removed

%%%% plot calibrated data
H = figure(3);
cmap = parula(12);
set(H,'PaperUnits','centimeter','units','centimeter',...
    'papersize',[16 14],'Position',[20 10 16 14],'color',[1 1 1])
t = tiledlayout(2,2,"TileSpacing","compact");

nexttile
hold on
plot(CaTitData(:,1),calCa,'-','color',cmap(1,:));
plot(tempAc(:,5),tempAc(:,7).*1000,'-k')
plot(tempAc(:,5),acCaNaOH(:,1).*1000,'-','color',[1 102/255 102/255])
ylabel('\alpha_{Ca^{2+}} \times10^3')
xlabel('time (s)')
set(gca,'box','on','fontsize',8)
xL = get(gca,'xlim');
set(gca,'xlim',[0 xL(2)])
legend('measured','calculated','calculated w/missing DIC',...
    'location','northwest','fontsize',6,'box','off')

nexttile
plot(tempAc(:,5),DICcalc(:,1))
hold on
plot(tempAc(:,5),DICcalc(:,2)./1000)
ylabel('DIC (mmol/kg)')
yL1 = get(gca,'ylim');
yyaxis right
plot(tempAc(:,5),0 - (tempAc(:,4).*metaData.conc_NaOH(i)*1000/volIn*metaData.density(i) ...
    - tempAc(round(xLoc/loopStep,0)+1,4).*metaData.conc_NaOH(i)*1000/volIn*metaData.density(i)))
yL2 = get(gca,'ylim');
set(gca,'ylim',[yL1(2)-metaData.init_cDIC(i)/1000 - (yL1(2)-yL1(1)) ...
    yL1(2)-metaData.init_cDIC(i)/1000])
ylabel('DIC loss from NaOH titration (mmol/kg)')
legend('with iterative solve',...
    'with it. solve and meas. DIC',...
    'location','southwest','box','off','fontsize',6)
xlabel('time (s)')
set(gca,'box','on','fontsize',8)
xL = get(gca,'xlim');
set(gca,'xlim',[0 xL(2)])

nexttile
plot(tempAc(:,5),tempAc(:,8).*tempAc(:,9))
hold on
plot(tempAc(:,5),tempAc(:,10).*tempAc(:,9))
plot(tempAc(:,5),acCaNaOH(:,1).*acCaNaOH(:,2))
plot(tempAc(:,5),tempAc(:,12).*tempAc(:,11))
ylabel('IAP')
xlabel('time (s)')
set(gca,'box','on','fontsize',8,...
    'yscale','log')
ylim([1e-9 1e-6])
xL = get(gca,'xlim');
set(gca,'xlim',[0 xL(2)])
legend('without iterative solve','with iterative solve',...
    'using NaOH-derived DIC',...
    'with it. solve and meas. DIC',...
    'location','southeast','box','off','fontsize',6)

nexttile
yyaxis left
plot(tempAc(:,5),tempAc(:,2))
ylabel('pH (NBS)')
ylim([8.5 9.2])
hold on
yyaxis right
plot(tempAc(:,5),tempAc(:,3))
ylabel('temperature (\circC)')
xlabel('time (s)')
set(gca,'box','on','fontsize',8)
xL = get(gca,'xlim');
set(gca,'xlim',[0 xL(2)],'ylim',[18 26])
t.Padding = 'compact';

print(H,'-dpng','-r600',...
    [metaData.experiment{i} ('_') num2str(i) ('_data')])
close(figure(3))

dataTab = table(tempAc(:,1),tempAc(:,2),tempAc(:,3),tempAc(:,4),...
    tempAc(:,5),tempAc(:,6),tempAc(:,7).*1000,tempAc(:,8).*1000,tempAc(:,9).*1000,...
    tempAc(:,10).*1000,tempAc(:,11).*1000,tempAc(:,12).*1000,...
    acCaNaOH(:,1).*1000,acCaNaOH(:,2).*1000,...
    tempAc(:,7).*tempAc(:,8),tempAc(:,9).*tempAc(:,10),tempAc(:,11).*tempAc(:,12),...
    acCaNaOH(:,1).*acCaNaOH(:,2),...
    tempAc(:,13),...
    DICcalc(:,1),DICcalc(:,2),DICNaOH,...
    MgCaConc(:,1),MgCaConc(:,2),MgCaConc(:,2)./MgCaConc(:,1),...
    acCaNaOH(:,3),totalCa,...
    'variablenames',...
    {'time (pH; s)','pH (NBS)','temperature (oc)','NaOH vol. (ml)',...
    'time (Ca; s)','Ca (mV)','alpha Ca2+ x103','alpha CO32- x103',...
    'it. alpha Ca2+ x103',...
    'it. alpha CO32- x103','it. alpha Ca2+ x103 +DIC','it. alpha CO32- x103 +DIC',...
    'it. alpha Ca2+ x103 +NaOH DIC','it. alpha CO32- x103 +NaOH DIC',...
    'IAP','it. IAP','it. IAP +meas. DIC',...
    'it. IAP +NaOH DIC',...
    'alpha Ca2+ x103 measured',...
    'DIC it. (mmol/kg)','DIC it. w/meas. (mmol/kg)','DIC from NaOH (mmol/kg)',...
    '[Ca] from it. sol. (mmol/kg)','[Mg] (mmol/kg)','Mg/Ca',...
    '[Ca] from NaOH DIC (mmol/kg)','total titrated Ca (mmol/kg)',...
    });


writetable(dataTab,...
    [metaData.experiment{i} ('_') num2str(i) ('_calibrated_titration_data_') ('.csv')])

save([metaData.experiment{i} ('_') num2str(i) ('_workspace') ('.mat')])

catch err
   filePre = [('errorlog_') num2str(i) ('_') metaData.experiment{i} ('.txt')];
   fid3 = fopen(filePre,'a+'); 
   fprintf(fid3,'%s\n',err.message);
   fprintf(fid3, '%s', err.getReport('extended', 'hyperlinks','off'));
   fclose(fid3);
end

end
end
close(f)