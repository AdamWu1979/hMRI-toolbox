function fn_out = hmri_MPMsmooth(fn_wMPM, fn_mwTC, fn_TPM, fwhm, l_TC)
% Applying tissue specific smoothing, aka. weighted averaging, in order to 
% limit partial volume effect. 
% 
% FORMAT
%   fn_out = hmri_MPMsmooth(fn_wMPM, fn_mwTC, fn_TPM, fwhm)
% 
% INPUT
% - fn_wMPM : filenames (char array) of the warped MPM, i.e. the
%             w*MT/R1/R2s/A.nii files
% - fn_mwTC : filenames (char array) of the modulated warped tissue
%             classes, i.e. the mwc1/2*.nii files
% - fn_TPM  : filenames (char array) of the a priori tissue probability 
%             maps to use, matching those in fn_mwTC
% - fwhm    : width of smoothing kernel in mm [6 by def.]
% - l_TC    : explicit list of tissue classes used [1:nTC by def.]
% 
% OUTPUT
% - fn_out  : cell array (one cell per MPM) of filenames (char array) of 
%             the "smoothed tissue specific MPMs".
% 
% REFERENCE
% Draganski et al, 2011, doi:10.1016/j.neuroimage.2011.01.052
%_______________________________________________________________________
% Copyright (C) 2017 Cyclotron Research Centre

% Written by C. Phillips.
% Cyclotron Research Centre, University of Liege, Belgium


% NOTES:
% this works for one subject at a time, i.e. in the classic case of 4 MPMs 
% and GM/WM tissue classes take the 
% + 4 warped quantitative maps (in fn_wMPM) 
% + 2 modulated warped tissue class maps in fn_mwTC (e.g. mwc1*.nii and 
%   mwc2*.nii)
% + 2 TPMs matching the fn_mwTC
% 
% In the VBQ toolbox, one typically considers GM/WM to produce fin-images, 
% aka. fin_uni/dart_c1/2* images. The key word "uni"/"dart" come from
% either maps warped by unified segmentation only, or Dartel, respectively.
% On top of these 2, there was also a combined GM+WM fin-image created: 
% fin_uni/dart_bb* images -> I am skipping this for the moment. 
% 
% If different tissue classes were used then the explicit list of tissue 
% classes (l_TC) could come in handy to keep the numbering of resulting 
% images in line with their tissue class index.
% 
% In the _run function
% - the exact tissue class considered is defined by the index in the name
%   of the fn_mwTC files. So if mwc1*.nii and mwc2*.nii are passed, then
%   the 1st and 2nd tissue class are used from the TPM
% - Just pass the full name of the TPM, without subvolume index, the exact 
%   TC used is defined by the fn_mwTC
%
% FUTURE:
% With present computer having large amounts of RAM, we could do most of
% the image calculation direction by loading the nifti files directly. This
% would eschew the use of spm_imcalc and its annoying messages...) and
% possibly be a bit faster. 
% Not sure how to perform the Gaussian smoothingn though. Probably some
% re-implementation could do the trick.

if nargin<4, fwhm = 6; end
if nargin<3,
    error('hMRI:smoothing','Provide 4 input, see help.');
end

% Count images and check
nMPM = size(fn_wMPM,1);
nTC  = size(fn_mwTC,1);
nTPM = size(fn_TPM,1);
if nTC~=nTPM
    error('hMRI:smoothing','Mismatched number of tissue classes.')
end
if nargin<5 || numel(l_TC)~=nTC
    % Get list of TC indexes if not provided
    l_TC = 1:nTC;
end

% Flags for image calculation
ic_flag = struct(...
    'dtype', 16, ... % keep things in floats
    'interp', -4);   % 4th order spline interpolation

% Initialize output and loop over MPMs
fn_out = cell(nMPM,1);
for ii=1:nMPM
    % ii^th MPM to be treated
    fn_wMPM_ii = fn_wMPM(ii,:) ;
    
    % Get the TC-weighted MPM -> p-images
    p = cell(nTC,1);
    for jj=1:nTC
        % MPM weighted with its own GM/WM/lesion, and a priori>.05
        tmp = char(fn_wMPM_ii, fn_mwTC(jj,:), fn_TPM(jj,:)); % i1, i2, i3
        p_tmp = spm_imcalc( tmp, ...
            spm_file(fn_wMPM_ii,'prefix',['p',num2str(l_TC(jj)),'_']), ...
            '(i1.*i2).*(i3>0.05)',ic_flag);
        p{jj} = p_tmp.fname;
    end
    
    % Smooth TC -> m-images
    m = cell(nTC,1);
    for jj=1:nTC
        m{jj} = spm_file(fn_mwTC(jj,:),'prefix','s','number','');
        spm_smooth(fn_mwTC(jj,:),m{jj},fwhm); % smooth mwc(jj)
    end
    
    % Smooth weighted MPM (p) -> n-images
    n = cell(nTC,1);
    for jj=1:nTC
        n{jj} = spm_file(p{jj},'prefix','s');
        spm_smooth(p{jj},n{jj},fwhm);
    end
    
    % calculate signal (n./m) + masking smoothed TC>.05
    q = cell(nTC,1);
    for jj=1:nTC
        q{jj} = spm_file(p{jj},'prefix','wa');
        spm_imcalc(char(n{jj},m{jj}), ... % i1, i2
            q{jj}, ...
            '(i1./i2).*(i2>0.05)',ic_flag);
    end
    
    fn_out{ii} = char(q); % saved as char array
    
    fn_2delete = char(char(p),char(m),char(n));
    for jj=1:size(fn_2delete,1)
        delete(deblank(fn_2delete(jj,:)));
    end
end

end

