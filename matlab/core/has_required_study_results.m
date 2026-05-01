function tf = has_required_study_results(model)
%HAS_REQUIRED_STUDY_RESULTS Detect whether the standard datasets/solutions exist.
    tf = has_dataset(model, 'dsetEig') && has_dataset(model, 'dsetTime') && ...
         has_solution(model, 'sol1') && has_solution(model, 'sol2');
end

function tf = has_dataset(model, tag)
    tf = true;
    try
        model.result().dataset(tag);
    catch
        tf = false;
    end
end

function tf = has_solution(model, tag)
    tf = true;
    try
        model.sol(tag);
    catch
        tf = false;
    end
end