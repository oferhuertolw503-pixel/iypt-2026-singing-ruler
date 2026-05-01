function data = read_json_file(path)
%READ_JSON_FILE Read JSON text and strip a UTF-8 BOM when present.

    txt = fileread(path);
    if ~isempty(txt) && double(txt(1)) == 65279
        txt = txt(2:end);
    end
    data = jsondecode(txt);
end
