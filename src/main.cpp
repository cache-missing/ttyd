#ifdef __cplusplus
extern "C" {
#endif

int start_tty(bool writable, bool once, int port, const char *interface, const char *credential, const char *cwd,
              int cmd_argc, char **cmd_argv);

#ifdef __cplusplus
}
#endif

int main(int argc, char **argv) {
  const char *cmd[] = {"bash", nullptr};  // Define an array of const char* (string pointers)
  start_tty(true, true, 8080, nullptr, nullptr, nullptr, 1, (char **)cmd); // Cast to char** to match function signature
}
