function ensure_dir(path)
%ENSURE_DIR Create a directory when it does not exist.
    if exist(path, "dir") ~= 7
        mkdir(path);
    end
end