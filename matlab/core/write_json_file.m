function write_json_file(path, data)
%WRITE_JSON_FILE Write JSON text with a trailing newline.

    txt = jsonencode(data, PrettyPrint=true);
    fid = fopen(path, "w", "n", "UTF-8");
    if fid < 0
        error("Cannot open file for writing: %s", path);
    end
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, "%s\n", txt);
end
