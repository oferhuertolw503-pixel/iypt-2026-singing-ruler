function run_default_studies(model)
%RUN_DEFAULT_STUDIES Run std1 and std2 when present.

    arguments
        model
    end

    fprintf("Running eigenfrequency study std1...\n");
    model.study("std1").run();
    fprintf("std1 complete.\n");

    fprintf("Running transient study std2...\n");
    model.study("std2").run();
    fprintf("std2 complete.\n");
end
