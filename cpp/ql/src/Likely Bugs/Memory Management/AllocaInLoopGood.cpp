char *dir_path;
char **dir_entries;
int count;

for (int i = 0; i < count; i++) {
  char *path = (char*)malloc(strlen(dir_path) + strlen(dir_entry[i]) + 2);
  // use path
  free(path);
}
