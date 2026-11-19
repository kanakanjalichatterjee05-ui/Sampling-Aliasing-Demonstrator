function SamplingAliasingDemo1
% SAMPLINGALIASINGDEMO  Interactive sampling & aliasing demonstrator (ECE-DSP-301).
%   Run with:  SamplingAliasingDemo      (base MATLAB only, no toolboxes)
%
%   Demos included:
%     1) Undersampling demonstration   (aliasing, fs < 2 f_in)
%     2) Critical sampling demonstration (fs = 2 f_in)
%     3) Oversampling demonstration    (fs >> 2 f_in, guard band)
%     4) Phase sensitivity demonstration (animated sweep of sampling phase)
%   Phase phi = offset of the sampling instants from the signal peaks.

    % ---------------- Build the GUI ----------------
    fig  = uifigure('Name','Sampling & Aliasing Demonstrator','Position',[60 40 1250 760]);
    main = uigridlayout(fig,[1 2]);
    main.ColumnWidth = {320,'1x'};

    ctrl = uigridlayout(main,[16 1]);
    ctrl.RowHeight = [repmat({'fit'},1,15), {'1x'}];
    ctrl.Padding = [12 12 12 12];  ctrl.RowSpacing = 4;

    lblFin = uilabel(ctrl);
    sFin = uislider(ctrl,'Limits',[10 300],'Value',100,'MajorTicks',[],'MinorTicks',[]);
    lblFs  = uilabel(ctrl);
    sFs  = uislider(ctrl,'Limits',[20 1000],'Value',120,'MajorTicks',[],'MinorTicks',[]);
    lblPh  = uilabel(ctrl);
    sPh  = uislider(ctrl,'Limits',[0 180],'Value',0,'MajorTicks',[],'MinorTicks',[]);
    lblKc  = uilabel(ctrl);
    sKc  = uislider(ctrl,'Limits',[0.2 1],'Value',1,'MajorTicks',[],'MinorTicks',[]);
    uilabel(ctrl,'Text','Waveform','FontWeight','bold');
    ddWave = uidropdown(ctrl,'Items',{'Sine','Square','Triangle'},'Value','Sine');
    b1 = uibutton(ctrl,'Text','Undersampling demonstration (100 / 120 Hz)');
    b2 = uibutton(ctrl,'Text','Critical sampling demonstration (100 / 200 Hz)');
    b3 = uibutton(ctrl,'Text','Oversampling demonstration (100 / 1000 Hz)');
    b4 = uibutton(ctrl,'Text','Phase sensitivity demonstration (animate)');
    info = uilabel(ctrl,'WordWrap','on','VerticalAlignment','top');

    plots = uigridlayout(main,[3 1]);
    plots.RowHeight = {'1x','1x',190};
    axT = uiaxes(plots);
    axF = uiaxes(plots);
    axP = uiaxes(plots);

    demo = '';   % text describing the active demonstration

    % ---------------- Callbacks ----------------
    sFin.ValueChangingFcn = @(~,e) refresh('fin',e.Value);
    sFs.ValueChangingFcn  = @(~,e) refresh('fs',e.Value);
    sPh.ValueChangingFcn  = @(~,e) refresh('ph',e.Value);
    sKc.ValueChangingFcn  = @(~,e) refresh('kc',e.Value);
    sFin.ValueChangedFcn  = @(~,~) manual();
    sFs.ValueChangedFcn   = @(~,~) manual();
    sPh.ValueChangedFcn   = @(~,~) manual();
    sKc.ValueChangedFcn   = @(~,~) manual();
    ddWave.ValueChangedFcn = @(~,~) manual();
    b1.ButtonPushedFcn = @(~,~) runDemo(100,120,0,'under');
    b2.ButtonPushedFcn = @(~,~) runDemo(100,200,0,'critical');
    b3.ButtonPushedFcn = @(~,~) runDemo(100,1000,0,'over');
    b4.ButtonPushedFcn = @(~,~) runPhaseDemo();

    refresh();

    % ---------------- Nested functions ----------------
    function manual()
        demo = '';
        refresh();
    end

    function runDemo(fin,fs,ph,kind)
        sFin.Value = fin;  sFs.Value = fs;  sPh.Value = ph;
        switch kind
            case 'under'
                demo = ['UNDERSAMPLING DEMO: fs < 2 f_in. The 100 Hz tone folds to ' ...
                        '20 Hz; the reconstruction is a false low-frequency tone.'];
            case 'critical'
                demo = ['CRITICAL SAMPLING DEMO: fs = 2 f_in gives exactly 2 samples ' ...
                        'per cycle. Move the phase slider: captured amplitude = A|cos(phi)|.'];
            case 'over'
                demo = ['OVERSAMPLING DEMO: fs = 10 f_in (10 samples/cycle). Wide guard ' ...
                        'band, near-perfect reconstruction, relaxed anti-alias filter.'];
        end
        refresh();
    end

    function runPhaseDemo()
        sFin.Value = 100;  sFs.Value = 200;
        demo = ['PHASE SENSITIVITY DEMO: fs = 2 f_in. Sweeping phi from 0 to 180 deg. ' ...
                'Amplitude falls to 0 at phi = 90 deg (samples hit zero crossings).'];
        for ph = [0:3:180, 180:-3:0]
            sPh.Value = ph;
            refresh();
            drawnow;
            pause(0.03);
        end
    end

    function refresh(name,val)
        % Read control values; 'val' overrides one control while a slider is dragged
        p.fin = round(sFin.Value);
        p.fs  = round(sFs.Value);
        p.ph  = round(sPh.Value);
        p.kc  = sKc.Value;
        if nargin > 0
            if strcmp(name,'kc'), p.kc = val; else, p.(name) = round(val); end
        end
        fin = p.fin;  fs = p.fs;  ph = p.ph;  kc = p.kc;  wave = ddWave.Value;

        lblFin.Text = sprintf('Signal frequency f_in: %d Hz',fin);
        lblFs.Text  = sprintf('Sampling frequency fs: %d Hz',fs);
        lblPh.Text  = sprintf('Sampling phase offset phi: %d deg',ph);
        lblKc.Text  = sprintf('Reconstruction cutoff: %.2f x (fs/2)',kc);

        % 1) Continuous-time signal (5 cycles)
        Tdur = 5/fin;
        t = linspace(0,Tdur,5001);
        x = gen(t,fin,wave);

        % 2) Ideal sampler with phase offset phi (phi = 0 -> samples on the peaks)
        t0 = (0.25 + ph/360)/fin;
        ts = t0 + (0:max(floor((Tdur-t0)*fs),1))/fs;
        xs = gen(ts,fin,wave);

        % 3) Sinc (Whittaker-Shannon) reconstruction with adjustable cutoff
        fc = kc*fs/2;
        xr = (2*fc/fs) * (mysinc(2*fc*(t(:) - ts(:).')) * xs(:));
        xr = xr.';

        % 4) FFT of a longer sampled record (256 samples, Hann window)
        Ns = 256;  N = 4096;
        xsf = gen(t0 + (0:Ns-1)/fs,fin,wave);
        w = 0.5 - 0.5*cos(2*pi*(0:Ns-1)/(Ns-1));
        X = abs(fftshift(fft(xsf.*w,N))) * 2/sum(w);
        f = (-N/2:N/2-1)*fs/N;
        [~,iPk] = max(X);
        fPeak = abs(f(iPk));

        % Theory: apparent frequency of the fundamental
        k = round(fin/fs);
        fAlias = abs(fin - k*fs);

        if abs(fs-2*fin) < 1e-9
            regime = 'CRITICAL SAMPLING (fs = 2 f_in)';
        elseif fs > 2*fin
            regime = 'OVERSAMPLING (fs > 2 f_in): no aliasing';
        else
            regime = 'UNDERSAMPLING (fs < 2 f_in): ALIASING';
        end

        mid = t > 0.2*Tdur & t < 0.8*Tdur;
        err = sqrt(mean((x(mid) - xr(mid)).^2));
        ampCap = max(abs(xs));            % amplitude captured by the samples

        % Phase-sensitivity curve: captured amplitude vs phi for current fin, fs
        phis = 0:5:180;
        amp = zeros(size(phis));
        for i = 1:numel(phis)
            tt = (0.25 + phis(i)/360)/fin + (0:63)/fs;
            amp(i) = max(abs(gen(tt,fin,wave)));
        end

        % ---------------- Plots ----------------
        cla(axT); hold(axT,'on');
        plot(axT,t*1e3,x,'Color',[0.65 0.70 0.75],'LineWidth',1.5);
        stem(axT,ts*1e3,xs,'filled','Color',[0.15 0.39 0.92]);
        plot(axT,t*1e3,xr,'--','Color',[0.86 0.15 0.15],'LineWidth',2);
        hold(axT,'off');
        xlim(axT,[0 Tdur*1e3]);  ylim(axT,[-1.6 1.6]);  grid(axT,'on');
        xlabel(axT,'Time (ms)');  ylabel(axT,'Amplitude');
        title(axT,'Time domain: original, samples x[n], reconstruction');
        legend(axT,{'Original x(t)','Samples x[n]','Reconstructed x_r(t)'},'Location','northeast');

        cla(axF); hold(axF,'on');
        area(axF,f,X,'FaceColor',[0.75 0.85 0.98],'EdgeColor',[0.15 0.39 0.92],'LineWidth',1.5);
        xline(axF, fAlias,'--','Color',[0.86 0.15 0.15],'LineWidth',1.5);
        xline(axF,-fAlias,'--','Color',[0.86 0.15 0.15],'LineWidth',1.5);
        hold(axF,'off');
        xlim(axF,[-fs/2 fs/2]);  ylim(axF,[0 1.3]);  grid(axF,'on');
        xlabel(axF,'Frequency (Hz)  [shown over -fs/2 ... +fs/2]');
        ylabel(axF,'|X(f)|');
        title(axF,sprintf('Spectrum: detected peak %.1f Hz (red dashes = predicted alias %.1f Hz)',fPeak,fAlias));

        cla(axP); hold(axP,'on');
        plot(axP,phis,amp,'-','Color',[0.85 0.47 0.02],'LineWidth',2);
        if abs(fs-2*fin) < 1e-9
            plot(axP,phis,abs(cosd(phis)),'k:','LineWidth',1.5);
        end
        plot(axP,ph,ampCap,'o','MarkerSize',10,'MarkerFaceColor',[0.86 0.15 0.15], ...
             'MarkerEdgeColor','k');
        hold(axP,'off');
        xlim(axP,[0 180]);  ylim(axP,[0 1.1]);  grid(axP,'on');
        xlabel(axP,'Sampling phase offset \phi (deg)');
        ylabel(axP,'Captured amplitude');
        title(axP,'Phase sensitivity: captured amplitude vs \phi (dotted = A|cos\phi| at fs = 2 f_{in})');

        lines = {
            ['Regime: ' regime]
            sprintf('Nyquist rate: %d Hz   |   fs/2: %.1f Hz',2*fin,fs/2)
            sprintf('Guard band fs - 2 f_in: %d Hz',fs-2*fin)
            sprintf('Alias |f_in - k fs| = |%d - %d x %d| = %d Hz',fin,k,fs,fAlias)
            sprintf('Captured amplitude: %.3f  |  RMS error: %.3f',ampCap,err)
            };
        if ~isempty(demo), lines = [lines; {' '}; {demo}]; end
        info.Text = lines;
    end
end

% ---------------- Local helper functions ----------------
function x = gen(t,f,wave)
    switch wave
        case 'Sine',     x = sin(2*pi*f*t);
        case 'Square',   x = sign(sin(2*pi*f*t));
        case 'Triangle', x = (2/pi)*asin(sin(2*pi*f*t));
    end
end

function y = mysinc(x)
    % Normalized sinc, sin(pi x)/(pi x); avoids the Signal Processing Toolbox
    y = ones(size(x));
    k = (x ~= 0);
    y(k) = sin(pi*x(k)) ./ (pi*x(k));
end
