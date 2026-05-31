function quick_conclusion()
    proj = fullfile(fileparts(mfilename('fullpath')), '..', '..');
    addpath(genpath(fullfile(proj, 'matlab')));
    data_root = fullfile(proj, 'outputs/requested_adaptive/cases');

    listing = dir(fullfile(data_root, '**', 'data', 'frequencies.csv'));
    n = numel(listing);
    fprintf('Found %d cases\n', n);

    for i = 1:n
        d = listing(i).folder;
        rel = strrep(extractAfter(d, data_root), '\', '/');
        if startsWith(rel, '/'), rel = rel(2:end); end
        if endsWith(rel, '/data'), rel = rel(1:end-5); end

        ft = read_exported_numeric_csv(fullfile(d, 'frequencies.csv'));
        mt = read_exported_numeric_csv(fullfile(d, 'mic_pressure_timeseries.csv'));
        pt = read_exported_numeric_csv(fullfile(d, 'structure_probe_timeseries.csv'));

        rms_pa = rms(mt.p_pa);
        spl = 20*log10(max(rms_pa,1e-12)/20e-6);
        probe_mm = max(abs(pt.uz_m)) * 1000;

        fprintf('[%2d/%2d] %-50s f1=%.1f Hz  SPL=%.1f dB  probe=%.2f mm\n', ...
            i, n, rel(1:min(50,end)), ft.freq_hz(1), spl, probe_mm);
    end
    fprintf('Done.\n');
end
