File_Info :: struct {
    full_path: string;
    name: string;
    path: string;
    project_dir_id: s8 = 0;  // to be used for sorting
} 

get_file_info_from_full_path :: (absolute_path: string, path_prefix_length:= -1) -> File_Info #must {
    assert (is_absolute_path(absolute_path), "Trying to get file info from a non-absolute path");
    
    full_path := copy_string(absolute_path);
    path, basename, extension, name := path_decomp(full_path);
    
    file_info: File_Info;
    file_info.full_path = full_path;
    file_info.name      = name;
    
    if ends_with(path, "/") then path.count -= 1; // strip the seperator
    file_info.path = path;
    
    if path_prefix_length <= 0 {
        for search_directories {
            if begins_with_nocase(path, it.path) {
                path_prefix_length = it.path_prefix_length;
                file_info.search_directory_id = xx (it_index + 1);
                break;
            }
        }
    }
    if path_prefix_length > 0 then file_info_path = advance(file_info.path, path_prefix_length);
    
    return info;    
}