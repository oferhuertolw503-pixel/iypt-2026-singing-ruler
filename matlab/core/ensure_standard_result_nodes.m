function ensure_standard_result_nodes(model, spec)
%ENSURE_STANDARD_RESULT_NODES Create or refresh standard result nodes after solve.

    arguments
        model
        spec struct
    end

    ensure_solution_dataset(model, 'dsetEig', 'sol1');
    ensure_solution_dataset(model, 'dsetTime', 'sol2');
    ensure_table(model, 'tblFreq');
    ensure_eval_global_freq(model);
    ensure_beam_dataset(model, 'dsetEigBeam', 'dsetEig');
    ensure_cut_point(model, 'cptTip', 'dsetTime');
    ensure_mode_plot(model);
    ensure_tip_plot(model);
    if isfield(spec, "include_mic") && spec.include_mic
        ensure_mic_plot(model, spec.mic_expr);
    end
end

function ensure_solution_dataset(model, tag, solution_tag)
    if ~has_dataset(model, tag)
        model.result().dataset().create(tag, 'Solution');
    end
    model.result().dataset(tag).set('solution', solution_tag);
end

function ensure_beam_dataset(model, tag, data_tag)
    if ~has_dataset(model, tag)
        model.result().dataset().create(tag, 'Beam');
    end
    model.result().dataset(tag).set('data', data_tag);
    model.result().dataset(tag).set('physicsinterface', 'beam');
    model.result().dataset(tag).set('refinement', 2);
end

function ensure_cut_point(model, tag, data_tag)
    if ~has_dataset(model, tag)
        model.result().dataset().create(tag, 'CutPoint3D');
    end
    model.result().dataset(tag).set('data', data_tag);
    model.result().dataset(tag).set('pointx', 'L');
    model.result().dataset(tag).set('pointy', '0');
    model.result().dataset(tag).set('pointz', '0');
end

function ensure_table(model, tag)
    if ~has_table(model, tag)
        model.result().table().create(tag, 'Table');
    end
end

function ensure_eval_global_freq(model)
    if ~has_numerical(model, 'gevFreq')
        model.result().numerical().create('gevFreq', 'EvalGlobal');
    end
    model.result().numerical('gevFreq').set('data', 'dsetEig');
    model.result().numerical('gevFreq').set('expr', {'freq'});
    model.result().numerical('gevFreq').set('unit', {'Hz'});
    model.result().numerical('gevFreq').set('descr', {'Eigenfrequency'});
    model.result().numerical('gevFreq').set('table', 'tblFreq');
    try
        model.result().numerical('gevFreq').setResult();
    catch
    end
end

function ensure_mode_plot(model)
    if ~has_plot_group(model, 'pgMode')
        model.result().create('pgMode', 'PlotGroup3D');
    end
    model.result('pgMode').set('data', 'dsetEigBeam');
    model.result('pgMode').set('showlegends', false);
    if ~has_plot_feature(model, 'pgMode', 'line1')
        model.result('pgMode').create('line1', 'Line');
    end
    model.result('pgMode').feature('line1').set('expr', {'beam.disp'});
    model.result('pgMode').feature('line1').set('linetype', 'tube');
    if ~has_nested_plot_feature(model, 'pgMode', 'line1', 'def')
        model.result('pgMode').feature('line1').create('def', 'Deform');
    end
    model.result('pgMode').feature('line1').feature('def').set('expr', {'u', 'v', 'w'});
end

function ensure_tip_plot(model)
    if ~has_plot_group(model, 'pgTip')
        model.result().create('pgTip', 'PlotGroup1D');
    end
    model.result('pgTip').set('data', 'cptTip');
    if ~has_plot_feature(model, 'pgTip', 'ptgr1')
        model.result('pgTip').create('ptgr1', 'PointGraph');
    end
    model.result('pgTip').feature('ptgr1').set('expr', 'w');
    model.result('pgTip').feature('ptgr1').set('unit', 'm');
    model.result('pgTip').feature('ptgr1').set('descr', 'Tip displacement (z)');
end

function ensure_mic_plot(model, mic_expr)
    if ~has_plot_group(model, 'pgMic')
        model.result().create('pgMic', 'PlotGroup1D');
    end
    model.result('pgMic').set('data', 'cptTip');
    if ~has_plot_feature(model, 'pgMic', 'ptgr1')
        model.result('pgMic').create('ptgr1', 'PointGraph');
    end
    model.result('pgMic').feature('ptgr1').set('expr', mic_expr);
    model.result('pgMic').feature('ptgr1').set('unit', 'Pa');
    model.result('pgMic').feature('ptgr1').set('descr', 'Mic pressure (surrogate, linear radiation)');
end

function tf = has_dataset(model, tag)
    tf = true;
    try
        model.result().dataset(tag);
    catch
        tf = false;
    end
end

function tf = has_table(model, tag)
    tf = true;
    try
        model.result().table(tag);
    catch
        tf = false;
    end
end

function tf = has_numerical(model, tag)
    tf = true;
    try
        model.result().numerical(tag);
    catch
        tf = false;
    end
end

function tf = has_plot_group(model, tag)
    tf = true;
    try
        model.result(tag);
    catch
        tf = false;
    end
end

function tf = has_plot_feature(model, group_tag, feature_tag)
    tf = true;
    try
        model.result(group_tag).feature(feature_tag);
    catch
        tf = false;
    end
end

function tf = has_nested_plot_feature(model, group_tag, feature_tag, nested_tag)
    tf = true;
    try
        model.result(group_tag).feature(feature_tag).feature(nested_tag);
    catch
        tf = false;
    end
end
